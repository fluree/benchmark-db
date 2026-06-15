#!/usr/bin/env bash
# Bootstrap: QLever (native) on DBLP-core.
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/qlever}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-180}"

log() { echo "[qlever $(date +%H:%M:%S)] $*"; }

log "=== QLever DBLP-core bootstrap ==="

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq curl pigz unzip docker.io \
    libjemalloc2 libboost-program-options1.83.0 \
    libboost-iostreams1.83.0 libboost-url1.83.0
# AWS CLI v2 (not in Ubuntu 24.04 apt)
if ! command -v aws &>/dev/null; then
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi

# Extract QLever native binaries from the official image
log "Extracting QLever binaries..."
sudo systemctl start docker || true
sleep 3
CID=$(sudo docker create adfreiburg/qlever:latest)
sudo docker cp "$CID":/qlever/qlever-index /usr/local/bin/qlever-index
sudo docker cp "$CID":/qlever/qlever-server /usr/local/bin/qlever-server
sudo docker rm "$CID"
sudo chmod +x /usr/local/bin/qlever-{index,server}
log "QLever version: $(qlever-server --version 2>&1 | head -1 || true)"

# Python qlever control tool
sudo apt-get install -y -qq python3-pip python3-venv
python3 -m venv ~/qlever-venv
~/qlever-venv/bin/pip install -q qlever

mkdir -p ~/data ~/qlever ~/bench/queries ~/bench/outputs ~/results

# Data
log "Fetching data..."
aws s3 cp "$S3_DATA" ~/data/dblp.nt.gz

# Harness
log "Fetching harness..."
aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/
chmod +x ~/bench/run_benchmark.sh

# Index
log "Indexing (ulimit + STXXL_MEMORY required)..."
cd ~/qlever
ln -s ~/data/dblp.nt.gz dblp.nt.gz

cat > Qleverfile <<'EOF'
[data]
NAME = dblp
DESCRIPTION = dblp
[index]
INPUT_FILES     = dblp.nt.gz
CAT_INPUT_FILES = zcat ${INPUT_FILES}
SETTINGS_JSON   = { "num-triples-per-batch": 1000000, "group-by-hash-map-enabled": true }
VOCABULARY_TYPE = in-memory-compressed
STXXL_MEMORY    = 20G
[server]
PORT = 7015
ACCESS_TOKEN = dblp_token
MEMORY_FOR_QUERIES = 26G
CACHE_MAX_SIZE = 6G
TIMEOUT = 300s
[runtime]
SYSTEM = native
EOF

ulimit -n 1048576
~/qlever-venv/bin/qlever index
log "Index complete."

# Serve
log "Starting QLever server..."
~/qlever-venv/bin/qlever start
sleep 5

TOK=dblp_token
# Disable result cache
for p in cache-max-num-entries=0 cache-max-size=0B cache-max-size-single-entry=0B cache-max-size-lazy-result=0B; do
    curl -s -o /dev/null "http://localhost:7015/?access-token=$TOK&$p"
done

# Verify
COUNT=$(curl -s -X POST "http://localhost:7015/?access-token=$TOK" \
    -H "Accept: text/tab-separated-values" \
    --data 'SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' | tail -1)
log "COUNT(*) = $COUNT"

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
aws s3 sync ~/bench/outputs/           "$S3_RESULTS/query-outputs/"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
log "=== QLever bootstrap complete ==="
