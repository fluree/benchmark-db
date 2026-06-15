#!/usr/bin/env bash
#
# Drive the BSBM test driver across a matrix of cells against ONE engine endpoint
# (Fluree by default). BSBM owns its measurement: each cell is a randomized query
# mix run by `bsbmtools-0.2/testdriver`, producing QMpH / QpS / per-query timings
# into an XML file. This script just sweeps the matrix and names the outputs;
# parse them with parse_bsbm_xml.py.
#
# Matrix axes (set via flags/env):
#   USE CASES   explore | bi | update         (-c, comma-sep; default explore)
#   CLIENTS     -mt values (concurrency)       (-m, comma-sep; default "1")
#   CACHE       label only: cold | warm | pgwarm  (-k; recorded in output names —
#               the operator is responsible for putting the engine in that state,
#               i.e. restart + drop_caches for cold, warmup for warm)
#
# Cache + concurrency guidance (see README): cache state is a SINGLE-CLIENT axis
# (compare cold/warm at -mt 1); server-concurrency is a MULTI-CLIENT axis. Don't
# cross them blindly or the matrix explodes.
#
# Example (1M smoke — one explore cell, few runs):
#   ./run-matrix.sh -t datasets/bsbm-1m/td -c explore -m 1 -r 25 -w 10 -k warm \
#       -o reports/bsbm-1m/runs/smoke
#
# Example (1M latency block, cold):  -c explore,bi,update -m 1 -k cold
# Example (1M throughput ramp):      -c explore -m 4,8,16,32 -k warm
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$SCRIPT_DIR/bsbmtools-0.2"

# Defaults
TD=""
USECASES="explore"
CLIENTS="1"
RUNS=100
WARMUP=50
SEED=808080
CACHE="warm"
TIMEOUT_MS=0
RAMPUP=false
LEDGER="bsbm:main"
QUERY_URL=""           # default derived from HOST below
UPDATE_URL=""          # default derived; only used for the update use case
HOST="http://localhost:8090"
OUT="$SCRIPT_DIR/results"

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--td)        TD="$2"; shift 2 ;;
    -c|--usecases)  USECASES="$2"; shift 2 ;;
    -m|--clients)   CLIENTS="$2"; shift 2 ;;
    -r|--runs)      RUNS="$2"; shift 2 ;;
    -w|--warmup)    WARMUP="$2"; shift 2 ;;
    -k|--cache)     CACHE="$2"; shift 2 ;;
    -s|--seed)      SEED="$2"; shift 2 ;;
    --timeout-ms)   TIMEOUT_MS="$2"; shift 2 ;;
    --rampup)       RAMPUP=true; shift ;;
    -l|--ledger)    LEDGER="$2"; shift 2 ;;
    --host)         HOST="$2"; shift 2 ;;
    --query-url)    QUERY_URL="$2"; shift 2 ;;
    --update-url)   UPDATE_URL="$2"; shift 2 ;;
    -o|--out)       OUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -n "$TD" ]] || { echo "ERROR: -t/--td <test-driver data dir> required."; exit 1; }
[[ -d "$TD" ]] || { echo "ERROR: td dir not found: $TD"; exit 1; }
TD="$(cd "$TD" && pwd)"
[[ -x "$TOOLS/testdriver" ]] || { echo "ERROR: $TOOLS/testdriver missing — run setup-bsbmtools.sh."; exit 1; }

# Fluree endpoints (ledger-scoped: query returns sparql-results+xml the driver parses;
# update accepts form-encoded `update=` via -uqp update).
[[ -n "$QUERY_URL" ]]  || QUERY_URL="$HOST/v1/fluree/query/$LEDGER"
[[ -n "$UPDATE_URL" ]] || UPDATE_URL="$HOST/v1/fluree/update/$LEDGER"

mkdir -p "$OUT"

ucf_for() {
  case "$1" in
    explore) echo "usecases/explore/sparql.txt" ;;
    bi)      echo "usecases/businessIntelligence/sparql.txt" ;;
    update)  echo "usecases/exploreAndUpdate/sparql.txt" ;;
    *) echo "ERROR: unknown use case '$1' (explore|bi|update)" >&2; return 1 ;;
  esac
}

echo "=== BSBM matrix ==="
echo "  endpoint:  $QUERY_URL"
echo "  td (idir): $TD"
echo "  usecases:  $USECASES   clients: $CLIENTS   cache: $CACHE"
echo "  runs: $RUNS  warmup: $WARMUP  seed: $SEED  rampup: $RAMPUP"
echo "  out:       $OUT"
echo ""

IFS=',' read -ra UC_ARR <<< "$USECASES"
IFS=',' read -ra MT_ARR <<< "$CLIENTS"

for uc in "${UC_ARR[@]}"; do
  ucf="$(ucf_for "$uc")" || exit 1
  for mt in "${MT_ARR[@]}"; do
    tag="${uc}__c${mt}__${CACHE}"
    xml="$OUT/${tag}.xml"
    log="$OUT/${tag}.log"
    echo "--- cell: $tag ---"

    args=( -idir "$TD" -ucf "$ucf" -runs "$RUNS" -w "$WARMUP" -seed "$SEED" -o "$xml" )
    [[ "$mt" != "1" ]] && args+=( -mt "$mt" )
    [[ "$TIMEOUT_MS" != "0" ]] && args+=( -t "$TIMEOUT_MS" )
    $RAMPUP && args+=( -rampup )
    if [[ "$uc" == "update" ]]; then
      # Form-encoded SPARQL Update to Fluree's update endpoint.
      args+=( -u "$UPDATE_URL" -uqp update )
      [[ -f "$TD/dataset_update.nt" ]] && args+=( -udataset "$TD/dataset_update.nt" )
    fi

    # testdriver insists on running from the toolkit root.
    ( cd "$TOOLS" && ./testdriver "${args[@]}" "$QUERY_URL" ) 2>&1 | tee "$log" | tail -4
    echo "  -> $xml"
    echo ""
  done
done

echo "Done. Parse with:  python3 $SCRIPT_DIR/parse_bsbm_xml.py $OUT/*.xml"
