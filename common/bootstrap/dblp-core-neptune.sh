#!/usr/bin/env bash
# Bootstrap: Amazon Neptune (db.r6g.xlarge, 4c/32GB) on DBLP-core.
#
# Unlike the native engines, this does NOT install or serve a database — it drives
# the Neptune *bulk loader* from an in-VPC client (run this on the benchmark EC2 that
# can reach the cluster's :8182 endpoint), measures load time, and pushes results to S3.
#
# Provision the cluster + IAM role + S3 endpoint + gzip-split data FIRST — see
# ../engine-setup/neptune.md. This script assumes those exist.
#
# Required env vars:
#   NEPTUNE_ENDPOINT      - cluster writer endpoint host (no scheme/port)
#   NEPTUNE_IAM_ROLE_ARN  - IAM role ARN Neptune assumes to read S3
#   AWS_REGION            - region of the cluster AND the S3 bucket (e.g. us-east-1)
#   S3_NEPTUNE_SOURCE     - s3:// prefix of the gzip-split .nt.gz chunks
#   S3_RESULTS            - s3:// prefix for this engine's results (no trailing slash)
# Optional:
#   NEPTUNE_PORT          - default 8182
#   LOADER_PARALLELISM    - LOW|MEDIUM|HIGH|OVERSUBSCRIBE (default OVERSUBSCRIBE)
#   LOADER_FORMAT         - default ntriples
#   USE_AWSCURL           - "1" to sign requests (set if IAM DB auth is ON)
set -euo pipefail

if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

NEPTUNE_PORT="${NEPTUNE_PORT:-8182}"
LOADER_PARALLELISM="${LOADER_PARALLELISM:-OVERSUBSCRIBE}"
LOADER_FORMAT="${LOADER_FORMAT:-ntriples}"
export NEPTUNE_INSTANCE="${NEPTUNE_INSTANCE:-db.r8g.xlarge (4c/32GB)}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/neptune}"
: "${NEPTUNE_ENDPOINT:?set NEPTUNE_ENDPOINT}"
: "${NEPTUNE_IAM_ROLE_ARN:?set NEPTUNE_IAM_ROLE_ARN}"
: "${AWS_REGION:?set AWS_REGION}"
: "${S3_NEPTUNE_SOURCE:?set S3_NEPTUNE_SOURCE}"

BASE="https://${NEPTUNE_ENDPOINT}:${NEPTUNE_PORT}"
log() { echo "[neptune $(date +%H:%M:%S)] $*"; }

# curl vs awscurl (SigV4) depending on whether IAM DB auth is enabled.
req() {
    if [[ "${USE_AWSCURL:-0}" == "1" ]]; then
        awscurl --region "$AWS_REGION" --service neptune-db "$@"
    else
        curl -s "$@"
    fi
}

log "=== Neptune DBLP-core load ==="
log "Endpoint: $BASE  source: $S3_NEPTUNE_SOURCE  parallelism: $LOADER_PARALLELISM"

mkdir -p ~/results

# --- Health check ---
if ! req "$BASE/status" >/dev/null; then
    log "ERROR: cannot reach $BASE/status — is this box in the cluster's VPC/SG?"
    exit 1
fi

# --- Submit the load job ---
log "Submitting bulk-load job..."
LOAD_RESP=$(req -X POST "$BASE/loader" -H 'Content-Type: application/json' -d @- <<JSON
{
  "source": "${S3_NEPTUNE_SOURCE}",
  "format": "${LOADER_FORMAT}",
  "iamRoleArn": "${NEPTUNE_IAM_ROLE_ARN}",
  "region": "${AWS_REGION}",
  "failOnError": "FALSE",
  "parallelism": "${LOADER_PARALLELISM}",
  "mode": "NEW",
  "queueRequest": "TRUE"
}
JSON
)
LOAD_ID=$(echo "$LOAD_RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["payload"]["loadId"])' 2>/dev/null || true)
if [[ -z "$LOAD_ID" ]]; then
    log "ERROR: no loadId in response: $LOAD_RESP"
    exit 1
fi
log "loadId = $LOAD_ID"

# --- Poll to completion (outer wall-clock as a sanity bound) ---
START=$SECONDS
while true; do
    STATUS_JSON=$(req "$BASE/loader/${LOAD_ID}?details=true")
    STATUS=$(echo "$STATUS_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["payload"]["overallStatus"]["status"])' 2>/dev/null || echo "PARSE_ERROR")
    case "$STATUS" in
        LOAD_COMPLETED) log "Load completed."; break ;;
        LOAD_IN_PROGRESS|LOAD_NOT_STARTED|LOAD_IN_QUEUE)
            log "status=$STATUS (${SECONDS}s elapsed)..."; sleep 20 ;;
        *)
            log "ERROR: load ended with status=$STATUS"
            echo "$STATUS_JSON" | python3 -m json.tool | tee ~/results/neptune_load_error.json
            req "$BASE/loader/${LOAD_ID}?details=true&errors=true&page=1&errorsPerPage=20" \
                | python3 -m json.tool | tee -a ~/results/neptune_load_error.json || true
            aws s3 cp ~/results/neptune_load_error.json "$S3_RESULTS/neptune_load_error.json" || true
            exit 1 ;;
    esac
done
WALL=$((SECONDS - START))

# --- Extract the comparable metrics ---
python3 - "$STATUS_JSON" "$WALL" <<'PY' | tee ~/results/neptune_load.json
import json, sys
st = json.loads(sys.argv[1])["payload"]["overallStatus"]
wall = int(sys.argv[2])
load_s = st["totalTimeSpent"]                 # parse+insert seconds (the comparable figure)
records = st["totalRecords"]
dups = st["totalDuplicates"]
net = records - dups
import os
out = {
    "engine": "neptune",
    "instance": os.environ.get("NEPTUNE_INSTANCE", "db.r8g.xlarge (4c/32GB)"),
    "load_time_s": load_s,                     # <-- head-to-head vs Fluree import wall-clock
    "outer_wall_s": wall,
    "total_records": records,
    "duplicates": dups,
    "net_distinct_triples": net,
    "throughput_tr_s": round(net / load_s, 1) if load_s else None,
    "parsing_errors": st.get("parsingErrors"),
    "insert_errors": st.get("insertErrors"),
}
print(json.dumps(out, indent=2))
PY

# --- Sanity: COUNT(*) over the SPARQL endpoint ---
log "Verifying COUNT(*)..."
COUNT=$(req -X POST "$BASE/sparql" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'Accept: text/tab-separated-values' \
    --data-urlencode 'query=SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' | tail -1 || true)
log "COUNT(*) = $COUNT"

# --- Upload ---
aws s3 cp ~/results/neptune_load.json "$S3_RESULTS/neptune_load.json"
echo "done" | aws s3 cp - "$S3_RESULTS/load-done.flag"
log "=== Neptune load complete: see ~/results/neptune_load.json ==="
