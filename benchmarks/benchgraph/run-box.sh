#!/usr/bin/env bash
# Run the benchgraph suite on this box for each Pokec size: fresh ledger,
# fresh server (FLUREE_CYPHER_ALLOW_FULL_SCAN=1), full query set, teardown.
# Results land in ~/benchgraph/results/<size>.tsv, import times in
# ~/benchgraph/results/import_times.txt.
#
# Usage: run-box.sh [sizes]   (default: "small medium large")
set -uo pipefail

SIZES="${1:-small medium large}"
FLUREE_BIN="$HOME/fluree-src/target/release/fluree"
BG="$HOME/benchgraph"
declare -A NV=( [small]=10000 [medium]=100000 [large]=1632803 )

log() { echo "[run-box $(date +%H:%M:%S)] $*"; }
mkdir -p "$BG/results"
: > "$BG/results/import_times.txt"

for size in $SIZES; do
    log "=== pokec_$size ==="
    pkill -f "fluree server" 2>/dev/null; sleep 2

    dir="$HOME/fluree-data-$size"
    rm -rf "$dir"; mkdir -p "$dir"; cd "$dir"
    "$FLUREE_BIN" init >/dev/null

    # native .cypher bulk import — the same file Memgraph/Neo4j load (no Turtle conversion)
    src="$BG/data/pokec_${size}_import.cypher"; [[ "$size" == "large" ]] && src="$BG/data/pokec_large.setup.cypher"
    log "importing $src ..."
    start=$SECONDS
    "$FLUREE_BIN" create pokec --from "$src" > import_$size.log 2>&1
    dur=$((SECONDS - start))
    grep Imported import_$size.log | tail -1
    echo "$size: ${dur}s  $(grep Imported import_$size.log | tail -1)" >> "$BG/results/import_times.txt"

    FLUREE_CYPHER_ALLOW_FULL_SCAN=1 "$FLUREE_BIN" server start --listen-addr 127.0.0.1:8090 >/dev/null 2>&1
    for i in $(seq 1 60); do
        curl -s -o /dev/null http://127.0.0.1:8090/health && break; sleep 2
    done
    count=$(curl -s -X POST http://127.0.0.1:8090/v1/fluree/query/pokec:main \
        -H 'Content-Type: application/cypher' --data 'MATCH (n:User) RETURN count(*)' \
        | jq -r '.results[0].data[0].row[0]')
    log "server up, :User count = $count"

    "$BG/run_benchmark.sh" -r 5 -w 2 --num-vertices "${NV[$size]}" \
        -o "$BG/results/$size.tsv" 2>&1 | tail -6

    pkill -f "fluree server" 2>/dev/null; sleep 2
done
log "all sizes done"
