#!/usr/bin/env bash
# Bootstrap: QLever (native) on Wikidata Truthy (8.19B triples).
# Runs unattended on a fresh Ubuntu 24.04 r7a.16xlarge (64c/512GB/3TB);
# pushes results to S3 when done.
#
# Required env vars (export them yourself, or set by your orchestration wrapper):
#   S3_DATA, S3_RESULTS, BENCH_RUNS, BENCH_WARMUP, BENCH_TIMEOUT
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/wikidata-truthy/latest-truthy.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/qlever}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-300}"

log() { echo "[qlever $(date +%H:%M:%S)] $*"; }

log "=== QLever Wikidata-truthy bootstrap ==="

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
# Ubuntu 24.04 has no awscli apt package — use the snap
command -v aws >/dev/null || sudo snap install aws-cli --classic
sudo apt-get install -y -qq curl pigz docker.io \
    libjemalloc2 libboost-program-options1.83.0 \
    libboost-iostreams1.83.0 libboost-url1.83.0

# Extract QLever native binaries from the official image
log "Extracting QLever binaries..."
sudo systemctl start docker || true
sleep 3
CID=$(sudo docker create adfreiburg/qlever:latest)
sudo docker cp "$CID":/qlever/qlever-index /usr/local/bin/qlever-index
sudo docker cp "$CID":/qlever/qlever-server /usr/local/bin/qlever-server
sudo docker rm "$CID"
sudo chmod +x /usr/local/bin/qlever-{index,server}
QLEVER_VERSION=$(sudo docker image inspect adfreiburg/qlever:latest --format '{{.Id}} {{.Created}}' || true)
log "QLever image: $QLEVER_VERSION"

sudo apt-get install -y -qq python3-pip python3-venv
python3 -m venv ~/qlever-venv
~/qlever-venv/bin/pip install -q qlever

mkdir -p ~/data ~/qlever ~/bench/queries ~/bench/outputs ~/results

# Data (70.5 GB)
log "Fetching data..."
[ -f ~/data/latest-truthy.nt.gz ] || aws s3 cp --no-progress "$S3_DATA" ~/data/latest-truthy.nt.gz

# Harness
log "Fetching harness..."
aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/
chmod +x ~/bench/run_benchmark.sh

# Index. Wikidata-scale settings (verified on the 2026-06 run): 10M batch,
# on-disk-compressed vocab, 300G sort memory. The vocabulary merge opens
# ~800 partial vocab files — needs the raised fd limit (default 1024 fails).
log "Indexing (this took ~2h25m on the prior run)..."
cd ~/qlever
ln -sf ~/data/latest-truthy.nt.gz wikidata.nt.gz

cat > Qleverfile <<'EOF'
[data]
NAME = wikidata
DESCRIPTION = Wikidata truthy 2026-05-29
# (DESCRIPTION is required by newer qlever control tools — `qlever start` errors without it)
[index]
INPUT_FILES     = wikidata.nt.gz
CAT_INPUT_FILES = zcat ${INPUT_FILES}
SETTINGS_JSON   = { "num-triples-per-batch": 10000000, "group-by-hash-map-enabled": true }
VOCABULARY_TYPE = on-disk-compressed
STXXL_MEMORY    = 300G
[server]
PORT = 7015
ACCESS_TOKEN = wikidata_token
MEMORY_FOR_QUERIES = 200G
CACHE_MAX_SIZE = 6G
TIMEOUT = 300s
[runtime]
SYSTEM = native
EOF

ulimit -n 1048576
~/qlever-venv/bin/qlever index
log "Index complete. Size: $(du -sh ~/qlever | cut -f1)"

# Serve
log "Starting QLever server..."
~/qlever-venv/bin/qlever start
sleep 10

TOK=wikidata_token
# Disable result cache so every run re-executes (matches the no-cache protocol)
for p in cache-max-num-entries=0 cache-max-size=0B cache-max-size-single-entry=0B cache-max-size-lazy-result=0B; do
    curl -s -o /dev/null "http://localhost:7015/?access-token=$TOK&$p"
done

# Verify (expect ~8,180,599,054 — QLever dedups exact-duplicate triples)
COUNT=$(curl -s --max-time 600 -X POST "http://localhost:7015/?access-token=$TOK" \
    -H "Accept: text/tab-separated-values" \
    -H "Content-Type: application/sparql-query" \
    --data 'SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' | tail -1)
log "COUNT(*) = $COUNT"

# Hard gate: never benchmark a partial/empty load
if ! [ "${COUNT:-0}" -gt 8000000000 ] 2>/dev/null; then
    log "FATAL: load incomplete (COUNT=${COUNT:-empty}, expected ~8.18B) — not benchmarking"
    exit 1
fi

# Benchmark
log "Running benchmark..."
cd ~/bench
./run_benchmark.sh \
    --endpoint "http://localhost:7015" \
    --clear-url "http://localhost:7015/?access-token=$TOK&cmd=clear-cache" \
    -r "$BENCH_RUNS" -w "$BENCH_WARMUP" -t "$BENCH_TIMEOUT" \
    --queries ~/bench/queries \
    --save-outputs ~/bench/outputs \
    -o ~/results/qlever.tsv

python3 ~/bench/summarize.py ~/results/qlever.tsv > ~/results/qlever_summary.tsv

# Upload
log "Uploading results..."
aws s3 cp ~/results/qlever.tsv         "$S3_RESULTS/qlever.tsv"
aws s3 cp ~/results/qlever_summary.tsv "$S3_RESULTS/qlever_summary.tsv"
aws s3 sync --no-progress ~/bench/outputs/ "$S3_RESULTS/query-outputs/"
echo "COUNT=$COUNT" | aws s3 cp - "$S3_RESULTS/import-count.txt"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
log "=== QLever bootstrap complete ==="
