#!/usr/bin/env bash
# Bootstrap: Fluree v4.0.6 resource-scaling on DBLP-core.
# Runs unattended on a fresh Ubuntu 24.04 box; pushes results to S3 when done.
#
# Required env vars (set by launch script):
#   S3_DATA          - s3://... path to dblp-2026-06-01.nt.gz
#   S3_RESULTS       - s3://... prefix for this config's results (no trailing slash)
#   CONFIG_LABEL     - e.g. "64gb-16c" (used for TSV filenames)
#   MEMORY_BUDGET_MB - override import memory budget (leave empty for auto)
#   BENCH_RUNS       - timed runs per query (default 3)
#   BENCH_WARMUP     - warmup runs (default 1)
#   BENCH_TIMEOUT    - per-query timeout seconds (default 180)
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/fluree-scaling}"
CONFIG_LABEL="${CONFIG_LABEL:-unknown}"
MEMORY_BUDGET_MB="${MEMORY_BUDGET_MB:-}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-180}"

# Published scaling run: Fluree v4.0.6. For a faithful reproduction, install the
# official v4.0.6 release (see ../engine-setup/fluree.md) instead of building from
# source; or pin FLUREE_BRANCH / FLUREE_COMMIT to build a specific ref from source.
FLUREE_BRANCH="${FLUREE_BRANCH:-main}"
FLUREE_COMMIT="${FLUREE_COMMIT:-}"

log() { echo "[fluree-scaling-${CONFIG_LABEL} $(date +%H:%M:%S)] $*"; }

log "=== Fluree DBLP-core scaling bootstrap (${CONFIG_LABEL}) ==="

# --- Dependencies ---
log "Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq curl git pigz unzip python3 build-essential
if ! command -v aws &>/dev/null; then
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi

# --- Rust + Fluree ---
FLUREE_BIN="$HOME/fluree-src/target/release/fluree"
if [[ -x "$FLUREE_BIN" ]]; then
    log "Reusing existing binary: $($FLUREE_BIN --version 2>&1 | head -1)"
else
    log "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    source "$HOME/.cargo/env"

    log "Cloning fluree/db (${FLUREE_BRANCH})..."
    rm -rf ~/fluree-src
    git clone --branch "$FLUREE_BRANCH" --depth 50 \
        https://github.com/fluree/db.git ~/fluree-src
    cd ~/fluree-src
    [[ -n "$FLUREE_COMMIT" ]] && git checkout "$FLUREE_COMMIT"

    log "Building fluree binary..."
    ~/.cargo/bin/cargo build --release -p fluree-db-cli
    log "Built: $($FLUREE_BIN --version 2>&1 | head -1)"
fi

# --- Data ---
mkdir -p ~/data ~/bench/queries ~/bench/outputs ~/results
if [[ -s ~/data/dblp.nt ]]; then
    log "Reusing existing dblp.nt"
else
    log "Fetching DBLP-core data from S3..."
    aws s3 cp "$S3_DATA" ~/data/dblp.nt.gz
    log "Decompressing..."
    pigz -dc ~/data/dblp.nt.gz > ~/data/dblp.nt
    log "Decompressed: $(wc -l < ~/data/dblp.nt) lines"
fi

# --- Fetch harness ---
log "Fetching harness from S3..."
HARNESS_BASE="${S3_RESULTS%/fluree-scaling/*}/harness"
aws s3 cp "${HARNESS_BASE}/run_benchmark.sh" ~/bench/run_benchmark.sh
aws s3 cp "${HARNESS_BASE}/summarize.py"     ~/bench/summarize.py
aws s3 sync "${HARNESS_BASE}/queries/"       ~/bench/queries/
chmod +x ~/bench/run_benchmark.sh

# --- Import ---
log "Importing DBLP-core into Fluree..."
mkdir -p ~/fluree-data
cd ~/fluree-data
$FLUREE_BIN init

IMPORT_ARGS=""
if [[ -n "$MEMORY_BUDGET_MB" ]]; then
    log "Using manual memory budget: ${MEMORY_BUDGET_MB} MB"
    IMPORT_ARGS="--memory-budget-mb $MEMORY_BUDGET_MB"
fi

log "Bulk-importing dblp.nt..."
IMPORT_START=$(date +%s)
$FLUREE_BIN create dblp --from ~/data/dblp.nt $IMPORT_ARGS
IMPORT_END=$(date +%s)
IMPORT_SECS=$((IMPORT_END - IMPORT_START))
log "Import done in ${IMPORT_SECS}s"

# Record peak RSS during import (best effort)
PEAK_RSS_KB=$(grep VmPeak /proc/$$/status 2>/dev/null | awk '{print $2}' || echo "0")
log "Peak RSS estimate: $((PEAK_RSS_KB / 1024)) MB"

# --- Server ---
log "Starting Fluree server..."
$FLUREE_BIN server start --listen-addr 127.0.0.1:8090

until curl -sf http://127.0.0.1:8090/health > /dev/null 2>&1; do sleep 3; done
log "Server ready."

COUNT=$(curl -s -X POST http://127.0.0.1:8090/v1/fluree/query/dblp:main \
    -H "Content-Type: application/sparql-query" \
    -H "Accept: text/tab-separated-values" \
    --data 'SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' | tail -1)
log "COUNT(*) = $COUNT"

# --- Benchmark ---
log "Running benchmark ($BENCH_WARMUP warmup + $BENCH_RUNS runs, ${BENCH_TIMEOUT}s timeout)..."
cd ~/bench
./run_benchmark.sh \
    --endpoint http://127.0.0.1:8090/v1/fluree/query/dblp:main \
    -r "$BENCH_RUNS" -w "$BENCH_WARMUP" -t "$BENCH_TIMEOUT" \
    --queries ~/bench/queries \
    --save-outputs ~/bench/outputs \
    -o ~/results/fluree-${CONFIG_LABEL}.tsv

python3 ~/bench/summarize.py ~/results/fluree-${CONFIG_LABEL}.tsv \
    > ~/results/fluree-${CONFIG_LABEL}_summary.tsv

log "Benchmark complete. Saving import metadata..."
cat > ~/results/meta-${CONFIG_LABEL}.txt <<EOF
config_label=${CONFIG_LABEL}
version=v4.0.6
commit=${FLUREE_COMMIT}
import_seconds=${IMPORT_SECS}
memory_budget_mb=${MEMORY_BUDGET_MB:-auto}
count=${COUNT}
EOF

# --- Upload ---
log "Uploading results to S3..."
aws s3 cp ~/results/fluree-${CONFIG_LABEL}.tsv         "$S3_RESULTS/fluree-${CONFIG_LABEL}.tsv"
aws s3 cp ~/results/fluree-${CONFIG_LABEL}_summary.tsv "$S3_RESULTS/fluree-${CONFIG_LABEL}_summary.tsv"
aws s3 cp ~/results/meta-${CONFIG_LABEL}.txt           "$S3_RESULTS/meta-${CONFIG_LABEL}.txt"
aws s3 sync ~/bench/outputs/                           "$S3_RESULTS/query-outputs/"

echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
log "=== Scaling bootstrap complete (${CONFIG_LABEL}) ==="
