#!/usr/bin/env bash
# Bootstrap: Fluree (v4.1.2 release) on DBLP-core.
# Runs unattended on a fresh Ubuntu 24.04 box; pushes results to S3 when done.
#
# Required env vars (export them yourself, or set by your orchestration wrapper):
#   S3_DATA     - s3://... path to dblp-2026-06-01.nt.gz
#   S3_RESULTS  - s3://... prefix for this engine's results (no trailing slash)
#   BENCH_RUNS  - timed runs per query (default 3)
#   BENCH_WARMUP - warmup runs (default 1)
#   BENCH_TIMEOUT - per-query timeout seconds (default 180)
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/fluree}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-180}"

# Published DBLP-core run: Fluree v4.1.2. For a faithful reproduction, install the
# official v4.1.2 release (see ../engine-setup/fluree.md) instead of building from
# source; or pin FLUREE_BRANCH / FLUREE_COMMIT to build a specific ref from source.
FLUREE_BRANCH="${FLUREE_BRANCH:-main}"
FLUREE_COMMIT="${FLUREE_COMMIT:-}"

log() { echo "[fluree $(date +%H:%M:%S)] $*"; }

log "=== Fluree DBLP-core bootstrap ==="

# --- Dependencies ---
log "Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq curl git pigz unzip python3 build-essential
# AWS CLI v2 (not in Ubuntu 24.04 apt) — arch-aware (x86_64 vs aarch64/Graviton)
if ! command -v aws &>/dev/null; then
    AWSCLI_ARCH=x86_64; [[ "$(uname -m)" == "aarch64" ]] && AWSCLI_ARCH=aarch64
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWSCLI_ARCH}.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi
# --- Fluree binary ---
# On ARM (Graviton) or when FLUREE_USE_INSTALLER=1, install the official prebuilt
# release (v4.1.0+, aarch64 & x86_64). Otherwise build from source, which lets you
# pin a branch/commit for from-source reproductions.
ARCH="$(uname -m)"
if [[ "${FLUREE_USE_INSTALLER:-}" == "1" || "$ARCH" == "aarch64" ]]; then
    if command -v fluree &>/dev/null; then
        log "Reusing existing binary: $(fluree --version 2>&1 | head -1)"
    else
        log "Installing Fluree via official installer ($ARCH)..."
        curl --proto '=https' --tlsv1.2 -LsSf \
            https://github.com/fluree/db/releases/latest/download/fluree-db-cli-installer.sh | sh
        # cargo-dist installs to ~/bin (with an env script); also cover ~/.local & ~/.cargo.
        export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
        [[ -f "$HOME/bin/env" ]] && source "$HOME/bin/env"
        [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
        log "Installed: $(fluree --version 2>&1 | head -1)"
    fi
    export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    FLUREE_BIN="$(command -v fluree)"
    cd ~
else
    FLUREE_BIN="$HOME/fluree-src/target/release/fluree"
    if [[ -x "$FLUREE_BIN" ]]; then
        log "Reusing existing binary: $($FLUREE_BIN --version 2>&1 | head -1)"
    else
        log "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        source "$HOME/.cargo/env"

        log "Cloning fluree/db ($FLUREE_BRANCH)..."
        rm -rf ~/fluree-src
        git clone --branch "$FLUREE_BRANCH" --depth 200 \
            https://github.com/fluree/db.git ~/fluree-src
        cd ~/fluree-src
        [[ -n "$FLUREE_COMMIT" ]] && git checkout "$FLUREE_COMMIT"

        log "Building fluree binary..."
        cargo build --release -p fluree-db-cli
        log "Built: $($FLUREE_BIN --version 2>&1 | head -1)"
    fi
    cd ~/fluree-src
fi

# --- Data ---
mkdir -p ~/data ~/bench/queries ~/bench/outputs ~/results
if [[ -s ~/data/dblp.nt ]]; then
    log "Reusing existing dblp.nt ($(wc -l < ~/data/dblp.nt) lines)"
else
    log "Fetching DBLP-core data from S3..."
    aws s3 cp "$S3_DATA" ~/data/dblp.nt.gz
    log "Data fetched. Decompressing..."
    pigz -dc ~/data/dblp.nt.gz > ~/data/dblp.nt
    log "Decompressed: $(wc -l < ~/data/dblp.nt) lines"
fi

# --- Fetch harness ---
log "Fetching harness from S3..."
aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/
chmod +x ~/bench/run_benchmark.sh

# --- Import ---
log "Importing DBLP-core into Fluree..."
mkdir -p ~/fluree-data
cd ~/fluree-data
$FLUREE_BIN init

log "Bulk-importing dblp.nt (this takes a while)..."
IMPORT_START=$SECONDS
$FLUREE_BIN create dblp --from ~/data/dblp.nt
FLUREE_LOAD_S=$((SECONDS - IMPORT_START))
log "Import complete in ${FLUREE_LOAD_S}s. Starting server..."
$FLUREE_BIN server start --listen-addr 127.0.0.1:8090 &
SERVER_PID=$!
sleep 15

# Verify COUNT(*)
log "Verifying import..."
COUNT=$(curl -s -X POST http://127.0.0.1:8090/v1/fluree/query/dblp:main \
    -H "Content-Type: application/sparql-query" \
    -H "Accept: text/tab-separated-values" \
    --data 'SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' | tail -1)
log "COUNT(*) = $COUNT"

# Record load metrics in the same shape as Neptune's neptune_load.json for head-to-head.
FLUREE_INSTANCE="${FLUREE_INSTANCE:-r8g.xlarge (4c/32GB)}"
NET_TRIPLES=$(echo "$COUNT" | tr -dc '0-9')
python3 - "$FLUREE_LOAD_S" "$NET_TRIPLES" "$FLUREE_INSTANCE" <<'PY' | tee ~/results/fluree_load.json
import json, sys
load_s = int(sys.argv[1]); net = int(sys.argv[2] or 0); inst = sys.argv[3]
print(json.dumps({
    "engine": "fluree",
    "instance": inst,
    "load_time_s": load_s,
    "net_distinct_triples": net,
    "throughput_tr_s": round(net / load_s, 1) if load_s else None,
}, indent=2))
PY
aws s3 cp ~/results/fluree_load.json "$S3_RESULTS/fluree_load.json" || true

# --- Benchmark ---
log "Running benchmark ($BENCH_WARMUP warmup + $BENCH_RUNS runs, ${BENCH_TIMEOUT}s timeout)..."
cd ~/bench
./run_benchmark.sh \
    --endpoint http://127.0.0.1:8090/v1/fluree/query/dblp:main \
    -r "$BENCH_RUNS" -w "$BENCH_WARMUP" -t "$BENCH_TIMEOUT" \
    --queries ~/bench/queries \
    --save-outputs ~/bench/outputs \
    -o ~/results/fluree.tsv

python3 ~/bench/summarize.py ~/results/fluree.tsv > ~/results/fluree_summary.tsv

# --- Upload ---
log "Uploading results to S3..."
aws s3 cp ~/results/fluree.tsv         "$S3_RESULTS/fluree.tsv"
aws s3 cp ~/results/fluree_summary.tsv "$S3_RESULTS/fluree_summary.tsv"
aws s3 sync ~/bench/outputs/           "$S3_RESULTS/query-outputs/"

# Signal done
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
log "=== Fluree bootstrap complete ==="
