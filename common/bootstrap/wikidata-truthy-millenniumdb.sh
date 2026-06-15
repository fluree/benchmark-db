#!/usr/bin/env bash
# Bootstrap: MillenniumDB on Wikidata Truthy (8.19B triples).
# Runs unattended on a fresh Ubuntu 24.04 r7a.16xlarge (64c/512GB/3TB);
# pushes results to S3 when done.
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/wikidata-truthy/latest-truthy.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/millenniumdb}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-300}"
# Commit used in the 2026-06-05 run (v1.0.0 lineage)
MDB_COMMIT="6118e08"

log() { echo "[mdb $(date +%H:%M:%S)] $*"; }

log "=== MillenniumDB Wikidata-truthy bootstrap ==="

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
# Ubuntu 24.04 has no awscli apt package — use the snap
command -v aws >/dev/null || sudo snap install aws-cli --classic
sudo apt-get install -y -qq curl git pigz python3 \
    build-essential cmake g++ make \
    libboost-all-dev libicu-dev libncurses-dev libssl-dev

mkdir -p ~/data ~/bench/queries ~/bench/outputs ~/results

# Data + harness (fetch in parallel with the build)
log "Fetching data and harness..."
{ [ -f ~/data/latest-truthy.nt.gz ] || aws s3 cp --no-progress "$S3_DATA" ~/data/latest-truthy.nt.gz; } &
DATA_PID=$!

aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh &
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py &
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/ &

# Build MillenniumDB at the pinned commit
log "Building MillenniumDB ($MDB_COMMIT)..."
[ -d ~/mdb-src ] || git clone https://github.com/MillenniumDB/MillenniumDB.git ~/mdb-src
cd ~/mdb-src
git checkout "$MDB_COMMIT"
cmake -B build -D CMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc) --target install || true  # install target may exit non-zero
MDB="$(pwd)/build/bin/mdb"
log "Built: $($MDB --version 2>&1 | head -1 || true)"

wait $DATA_PID
wait
chmod +x ~/bench/run_benchmark.sh

# Decompress to disk (~700 GB; 3 TB volume) — file import is the verified path
log "Decompressing data..."
pigz -dc ~/data/latest-truthy.nt.gz > ~/data/latest-truthy.nt
rm ~/data/latest-truthy.nt.gz

# Import with the wikidata-scale buffers from the prior run (~5h)
log "Importing into MillenniumDB (prior run: 5h03m)..."
$MDB import ~/data/latest-truthy.nt ~/mdb-db \
    --format ttl --buffer-strings 100GB --buffer-tensors 100GB
log "Import complete. Index size: $(du -sh ~/mdb-db | cut -f1)"
rm ~/data/latest-truthy.nt  # free 700 GB

# Serve (buffer total must stay well below 512 GB — 288GB+strings failed to
# allocate right after import on the prior run; this profile worked)
log "Starting MillenniumDB server..."
# NB: flag set verified against `mdb server --help` at this commit — there is
# no --unversioned-buffer; these match the 2026-06-05 run's config exactly.
$MDB server ~/mdb-db --port 1234 --threads 64 \
    --timeout "$BENCH_TIMEOUT" \
    --versioned-buffer 120GB \
    --strings-static 15GB --strings-dynamic 10GB \
    --tensors-static 5GB --tensors-dynamic 5GB &
MDB_PID=$!

# Buffer allocation (~155 GB) takes minutes — poll until the server answers
# (a fixed 30s sleep dies on the first refused connection under set -e).
log "Waiting for MDB server to answer..."
COUNT=""
for i in $(seq 1 180); do
    COUNT=$(curl -s --max-time 600 -X POST "http://localhost:1234/sparql" \
        -H "Accept: text/tab-separated-values" \
        --data 'SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' 2>/dev/null | tail -1) && [ -n "$COUNT" ] && break
    kill -0 $MDB_PID 2>/dev/null || { log "FATAL: server process died"; exit 1; }
    sleep 10
done
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
aws s3 sync --no-progress ~/bench/outputs/   "$S3_RESULTS/query-outputs/"
echo "COUNT=$COUNT" | aws s3 cp - "$S3_RESULTS/import-count.txt"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
kill $MDB_PID 2>/dev/null || true
log "=== MillenniumDB bootstrap complete ==="
