#!/usr/bin/env bash
# Stand up Neo4j Community + Memgraph on the box via Docker (host networking),
# load pokec <size>, and install the Python bolt driver. Idempotent.
#
# Usage: setup-engines-box.sh [size]   (default: small)
#
# Neo4j on Bolt 7687 / HTTP 7474 (auth neo4j/benchpass).
# Memgraph on Bolt 7688 (remapped to avoid clashing with Neo4j's 7687)
#   -- pass --bolt-port 7688 to bench_runner.py for memgraph.
set -uo pipefail

SIZE="${1:-small}"
BG="$HOME/benchgraph"
DATA="$BG/data"
NEO4J_VER="${NEO4J_VER:-5.26-community}"
MEMGRAPH_VER="${MEMGRAPH_VER:-3.11.0}"
POKEC_BASE="https://s3.eu-west-1.amazonaws.com/deps.memgraph.io/dataset/pokec/benchmark"

log() { echo "[engines $(date +%H:%M:%S)] $*"; }

log "=== deps: docker + python neo4j driver ==="
if ! command -v docker &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker.io
    sudo usermod -aG docker "$USER" || true
fi
sudo apt-get install -y -qq python3-pip >/dev/null 2>&1 || true
pip3 install --quiet --break-system-packages neo4j 2>/dev/null || pip3 install --quiet neo4j

DOCKER="sudo docker"

# --- raw import/index cypher (native, for neo4j/memgraph) ---
cd "$DATA"
imp="pokec_${SIZE}_import.cypher"
[[ "$SIZE" == "large" ]] && imp="pokec_large.setup.cypher"
[[ -s "$imp" ]] || { log "ERROR: $imp missing (run bootstrap first)"; exit 1; }
[[ -s neo4j.cypher ]]    || curl -sL -o neo4j.cypher    "$POKEC_BASE/neo4j.cypher"
[[ -s memgraph.cypher ]] || curl -sL -o memgraph.cypher "$POKEC_BASE/memgraph.cypher"

# ============================ Neo4j ============================
log "=== Neo4j $NEO4J_VER ==="
$DOCKER rm -f neo4j 2>/dev/null || true
$DOCKER run -d --name neo4j --network host \
    --env NEO4J_AUTH=neo4j/benchpass \
    --env NEO4J_server_memory_heap_max__size=8G \
    --env NEO4J_server_memory_pagecache_size=8G \
    "neo4j:$NEO4J_VER" >/dev/null
log "waiting for neo4j bolt..."
for i in $(seq 1 60); do
    $DOCKER exec neo4j cypher-shell -u neo4j -p benchpass "RETURN 1" &>/dev/null && break
    sleep 3
done

log "neo4j: index + load $imp ..."
# index first so the edge MATCHes seek instead of scan
$DOCKER exec -i neo4j cypher-shell -u neo4j -p benchpass < neo4j.cypher
# await index online, then load (nodes then edges, as ordered in the file)
$DOCKER exec neo4j cypher-shell -u neo4j -p benchpass "CALL db.awaitIndexes(300)" >/dev/null
start=$SECONDS
$DOCKER exec -i neo4j cypher-shell -u neo4j -p benchpass < "$imp"
log "neo4j load done in $((SECONDS-start))s"
n4=$($DOCKER exec neo4j cypher-shell -u neo4j -p benchpass "MATCH (n:User) RETURN count(*)" | tail -1)
log "neo4j :User count = $n4"

# ============================ Memgraph ============================
log "=== Memgraph $MEMGRAPH_VER (bolt 7688) ==="
$DOCKER rm -f memgraph 2>/dev/null || true
$DOCKER run -d --name memgraph -p 7688:7687 \
    "memgraph/memgraph:$MEMGRAPH_VER" \
    --telemetry-enabled=False >/dev/null
sleep 8
# mgconsole ships in the image
log "memgraph: index + load $imp ..."
$DOCKER exec -i memgraph mgconsole < memgraph.cypher 2>/dev/null || \
    cat memgraph.cypher | $DOCKER exec -i memgraph mgconsole
start=$SECONDS
$DOCKER exec -i memgraph mgconsole < "$imp"
log "memgraph load done in $((SECONDS-start))s"
mg=$(echo "MATCH (n:User) RETURN count(*);" | $DOCKER exec -i memgraph mgconsole 2>/dev/null | tail -2 | head -1)
log "memgraph :User count = $mg"

log "=== engines ready ==="
