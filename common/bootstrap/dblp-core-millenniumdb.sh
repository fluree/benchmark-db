#!/usr/bin/env bash
# Bootstrap: MillenniumDB v1.0.0 on DBLP-core.
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/millenniumdb}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-180}"

log() { echo "[mdb $(date +%H:%M:%S)] $*"; }

log "=== MillenniumDB DBLP-core bootstrap ==="

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq curl git pigz unzip python3 \
    build-essential cmake g++ make \
    libboost-all-dev libicu-dev libncurses-dev libssl-dev
# AWS CLI v2 (not in Ubuntu 24.04 apt)
if ! command -v aws &>/dev/null; then
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi

mkdir -p ~/data ~/bench/queries ~/bench/outputs ~/results

# Data + harness (fetch in parallel with the build)
log "Fetching data and harness..."
aws s3 cp "$S3_DATA" ~/data/dblp.nt.gz &
DATA_PID=$!

aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh &
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py &
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/ &

# Build MillenniumDB (can run while data downloads)
log "Building MillenniumDB..."
git clone --depth 1 https://github.com/MillenniumDB/MillenniumDB.git ~/mdb-src
cd ~/mdb-src
cmake -B build -D CMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc) --target install || true  # install target may exit non-zero
MDB="$(pwd)/build/bin/mdb"
log "Built: $($MDB --version 2>&1 | head -1)"

wait $DATA_PID
wait
chmod +x ~/bench/run_benchmark.sh

log "Decompressing data..."
pigz -dc ~/data/dblp.nt.gz > ~/data/dblp.nt

# Import (20GB + 20GB buffers, safe for 64 GB box)
log "Importing into MillenniumDB..."
$MDB import ~/data/dblp.nt ~/mdb-db \
    --format ttl --buffer-strings 20GB --buffer-tensors 20GB
log "Import complete. Index size: $(du -sh ~/mdb-db | cut -f1)"

# Serve
log "Starting MillenniumDB server..."
$MDB server ~/mdb-db --port 1234 --threads 16 \
    --timeout "$BENCH_TIMEOUT" \
    --versioned-buffer 22GB \
    --strings-static 4GB --strings-dynamic 4GB &
MDB_PID=$!
sleep 10

# Verify
COUNT=$(curl -s -X POST "http://localhost:1234/sparql" \
    -H "Accept: text/tab-separated-values" \
    --data 'SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' | tail -1)
log "COUNT(*) = $COUNT"

# Benchmark
log "Running benchmark..."
cd ~/bench
./run_benchmark.sh \
    --endpoint "http://localhost:1234/sparql" \
    -r "$BENCH_RUNS" -w "$BENCH_WARMUP" -t "$BENCH_TIMEOUT" \
    --queries ~/bench/queries \
    --save-outputs ~/bench/outputs \
    -o ~/results/millenniumdb.tsv

python3 ~/bench/summarize.py ~/results/millenniumdb.tsv > ~/results/millenniumdb_summary.tsv

# Upload
log "Uploading results..."
aws s3 cp ~/results/millenniumdb.tsv         "$S3_RESULTS/millenniumdb.tsv"
aws s3 cp ~/results/millenniumdb_summary.tsv "$S3_RESULTS/millenniumdb_summary.tsv"
aws s3 sync ~/bench/outputs/                 "$S3_RESULTS/query-outputs/"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
kill $MDB_PID 2>/dev/null || true
log "=== MillenniumDB bootstrap complete ==="
