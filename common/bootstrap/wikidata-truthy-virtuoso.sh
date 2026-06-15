#!/usr/bin/env bash
# Bootstrap: Virtuoso 7 (apt virtuoso-opensource-7) on Wikidata Truthy (8.19B).
# Runs unattended on a fresh Ubuntu 24.04 r7a.16xlarge (64c/512GB/3TB);
# pushes results to S3 when done.
#
# Wikidata gotcha (see common/engine-setup/virtuoso.md): geo:wktLiteral triples
# abort whole shards with RDFGE and there is no INI flag to disable geometry
# validation. The prior run loaded, found 629/1444 failed shards, filtered and
# reloaded them. Here we pre-filter wktLiteral while sharding — same final data
# (~11.5M geo-coordinate triples dropped, 0.14% of the dataset), no reload pass.
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/wikidata-truthy/latest-truthy.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/virtuoso}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-300}"
GRAPH="https://www.wikidata.org/"

log() { echo "[virtuoso $(date +%H:%M:%S)] $*"; }

log "=== Virtuoso Wikidata-truthy bootstrap ==="

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
# Ubuntu 24.04 has no awscli apt package — use the snap
command -v aws >/dev/null || sudo snap install aws-cli --classic
sudo apt-get install -y -qq pigz virtuoso-opensource curl python3

mkdir -p ~/data/shards ~/bench/queries ~/bench/outputs ~/results

sudo systemctl stop virtuoso-opensource-7 || true

# Patch the STOCK ini rather than replacing it: a from-scratch minimal ini is
# missing CaseMode and friends, which makes ld_dir create LOAD_LIST with
# lowercase column names and then fail with "SQ200: No column LL_FILE".
# 512 GB profile (verified loading 8B truthy): 32M buffers / 24M dirty ≈ 256 GB,
# 200 server threads for the parallel loaders.
INI=/etc/virtuoso-opensource-7/virtuoso.ini
if ! sudo grep -q '^;; stock-patched-for-wikidata' "$INI" 2>/dev/null; then
    # restore the pristine package ini in case a previous attempt replaced it
    sudo rm -f "$INI"
    sudo apt-get install --reinstall -y -qq -o Dpkg::Options::="--force-confmiss" virtuoso-opensource-7
    sudo systemctl stop virtuoso-opensource-7 || true
    sudo sed -i \
        -e 's/^NumberOfBuffers.*/NumberOfBuffers = 32000000/' \
        -e 's/^MaxDirtyBuffers.*/MaxDirtyBuffers = 24000000/' \
        -e 's/^ServerThreads[[:space:]]*=.*/ServerThreads = 200/' \
        -e 's#^DirsAllowed.*#DirsAllowed = ., /usr/share/virtuoso-opensource-7/vad, /home/ubuntu/data/shards#' \
        -e "s/^MaxQueryExecutionTime.*/MaxQueryExecutionTime = $BENCH_TIMEOUT/" \
        -e 's/^ResultSetMaxRows.*/ResultSetMaxRows = 10000000/' \
        -e 's/^MaxQueryCostEstimationTime.*/MaxQueryCostEstimationTime = 0/' \
        "$INI"
    # MaxQueryCostEstimationTime=0 disables the cost-estimator rejection (stock
    # 400s gate returns HTTP 500 "estimated execution time exceeds the limit"
    # for the big join queries before they even run; the real 300s execution
    # timeout still applies)
    sudo sed -i '1i ;; stock-patched-for-wikidata' "$INI"
fi

# Fresh database — an earlier broken-ini run leaves a poisoned LOAD_LIST schema
sudo rm -f /var/lib/virtuoso-opensource-7/db/virtuoso.db \
           /var/lib/virtuoso-opensource-7/db/virtuoso.trx \
           /var/lib/virtuoso-opensource-7/db/virtuoso.pxa \
           /var/lib/virtuoso-opensource-7/db/virtuoso-temp.db \
           /var/lib/virtuoso-opensource-7/db/virtuoso.log

sudo systemctl start virtuoso-opensource-7
sleep 10

# Data: download + re-shard into single-member .nt.gz shards with wktLiteral
# filtered out (rdf_loader_run decompresses .gz; more shards = more parallelism).
log "Fetching data..."
[ -f ~/data/latest-truthy.nt.gz ] || aws s3 cp --no-progress "$S3_DATA" ~/data/latest-truthy.nt.gz

# Harness (fetch while sharding would race on disk; it's quick, do it now)
log "Fetching harness..."
aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/
chmod +x ~/bench/run_benchmark.sh

if [ ! -f ~/data/.sharded ]; then
    log "Sharding (filtering wktLiteral)..."
    cd ~/data
    rm -f ~/data/shards/*
    pigz -dc latest-truthy.nt.gz \
        | LC_ALL=C grep -v wktLiteral \
        | split -l 4000000 -d -a 4 --filter='pigz -p 4 -c > ~/data/shards/$FILE.nt.gz' - shard_
    touch ~/data/.sharded
fi
NSHARDS=$(ls ~/data/shards | wc -l)
log "Shards ready: $NSHARDS"

# Load: 32 parallel loaders (one per 2 cores)
log "Loading ($NSHARDS shards, 32 parallel rdf_loader_run)..."
isql-vt 1111 dba dba exec="ld_dir('/home/ubuntu/data/shards', '*.nt.gz', '$GRAPH');"
for i in $(seq 1 32); do
    isql-vt 1111 dba dba exec="rdf_loader_run();" &
done
wait

# Retry pass: the parallel loaders can race on RDF_LANGUAGE (SR197) and abort a
# few shards; once the language tags exist a sequential re-load clears them.
# isql prints the result row followed by "n Rows. -- m msec" — take the first
# line that is purely a number (the result), not the last number (the msec).
isql_num() { awk '/^[[:space:]]*[0-9]+[[:space:]]*$/{print $1; exit}'; }
FAILED=$(isql-vt 1111 dba dba exec="SELECT COUNT(*) FROM DB.DBA.load_list WHERE ll_error IS NOT NULL;" | isql_num || echo 0)
if [[ "${FAILED:-0}" -gt 0 ]]; then
    log "Retrying $FAILED failed shards (sequential)..."
    isql-vt 1111 dba dba exec="UPDATE DB.DBA.load_list SET ll_state=0, ll_error=NULL WHERE ll_error IS NOT NULL;"
    isql-vt 1111 dba dba exec="rdf_loader_run();"
fi
isql-vt 1111 dba dba exec="checkpoint;"

STILL_FAILED=$(isql-vt 1111 dba dba exec="SELECT COUNT(*) FROM DB.DBA.load_list WHERE ll_error IS NOT NULL;" | isql_num || echo "?")
log "Load complete. Shards still failed: $STILL_FAILED"

# Verify (expect ~8.17B; wktLiteral triples are filtered)
COUNT=$(isql-vt 1111 dba dba exec="SPARQL SELECT (COUNT(*) AS ?c) WHERE { GRAPH <$GRAPH> { ?s ?p ?o } };" \
    | isql_num)
log "COUNT(*) = $COUNT"

# Hard gate: never benchmark a partial/empty load (expect ~8.16B after the
# wktLiteral filter). The first attempt at this run benchmarked COUNT=0.
if [ -z "${COUNT:-}" ] || [ "$COUNT" -lt 8000000000 ]; then
    log "FATAL: load incomplete (COUNT=${COUNT:-empty}, expected ~8.16B) — not benchmarking"
    exit 1
fi

# Benchmark (Virtuoso needs form-POST + default-graph-uri)
log "Running benchmark..."
cd ~/bench
./run_benchmark.sh \
    --endpoint "http://localhost:8890/sparql" \
    --post-form \
    --default-graph "$GRAPH" \
    -r "$BENCH_RUNS" -w "$BENCH_WARMUP" -t "$BENCH_TIMEOUT" \
    --queries ~/bench/queries \
    --save-outputs ~/bench/outputs \
    -o ~/results/virtuoso.tsv

python3 ~/bench/summarize.py ~/results/virtuoso.tsv > ~/results/virtuoso_summary.tsv

# Upload
log "Uploading results..."
aws s3 cp ~/results/virtuoso.tsv         "$S3_RESULTS/virtuoso.tsv"
aws s3 cp ~/results/virtuoso_summary.tsv "$S3_RESULTS/virtuoso_summary.tsv"
aws s3 sync --no-progress ~/bench/outputs/ "$S3_RESULTS/query-outputs/"
echo "COUNT=$COUNT failed_shards=$STILL_FAILED" | aws s3 cp - "$S3_RESULTS/import-count.txt"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
log "=== Virtuoso bootstrap complete ==="
