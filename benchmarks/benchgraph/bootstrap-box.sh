#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu 24.04 box for the benchgraph Pokec run:
# deps + rust + fluree @ pinned commit + pokec datasets converted to Turtle.
# Idempotent-ish: skips completed steps on re-run. Run under nohup; progress
# in ~/bootstrap.log, completion flag ~/bootstrap.done.
set -euo pipefail

# Overridable via env, e.g. FLUREE_COMMIT=abc123 SIZES="small" bootstrap-box.sh
FLUREE_BRANCH="${FLUREE_BRANCH:-fix/cypher-benchgraph-gaps}"
FLUREE_COMMIT="${FLUREE_COMMIT:-fce28d8e945106a635c83dda3ae0e9a730bcb423}"
SIZES="${SIZES:-small medium large}"
POKEC_BASE="https://s3.eu-west-1.amazonaws.com/deps.memgraph.io/dataset/pokec/benchmark"

log() { echo "[bootstrap $(date +%H:%M:%S)] $*"; }

log "=== deps ==="
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq curl git unzip python3 build-essential jq pigz

if ! command -v cargo &>/dev/null; then
    log "=== rust ==="
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
fi
source "$HOME/.cargo/env"

FLUREE_BIN="$HOME/fluree-src/target/release/fluree"
if [[ ! -x "$FLUREE_BIN" ]]; then
    log "=== clone + build fluree @ $FLUREE_COMMIT ==="
    rm -rf ~/fluree-src
    git clone --branch "$FLUREE_BRANCH" --depth 200 https://github.com/fluree/db.git ~/fluree-src
    cd ~/fluree-src
    git checkout "$FLUREE_COMMIT"
    cargo build --release -p fluree-db-cli
fi
log "fluree: $($FLUREE_BIN --version 2>&1 | head -1)"

log "=== datasets ($SIZES) ==="
mkdir -p ~/benchgraph/data
cd ~/benchgraph/data
for v in $SIZES; do
    [[ "$v" == "large" ]] && continue  # large handled below (gzipped)
    [[ -s pokec_${v}_import.cypher ]] || curl -sL -o pokec_${v}_import.cypher "$POKEC_BASE/pokec_${v}_import.cypher"
done
if [[ "$SIZES" == *large* && ! -s pokec_large.setup.cypher ]]; then
    curl -sL -o pokec_large.setup.cypher.gz "$POKEC_BASE/pokec_large.setup.cypher.gz"
    pigz -d pokec_large.setup.cypher.gz
fi

# Fluree ingests these .cypher dumps natively (fluree create --from file.cypher);
# no Turtle conversion step — the exact same file Memgraph/Neo4j load.

log "=== done ==="
touch ~/bootstrap.done
