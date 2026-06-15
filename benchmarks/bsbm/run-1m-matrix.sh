#!/usr/bin/env bash
#
# BSBM 1M throughput matrix against Fluree on a single box.
#
# Design: the server stays UP for the whole run and ledgers are created LIVE
# (no restarts). This avoids Fluree's startup "ledger preload" (which re-reads
# every ledger and scales with ledger count) and keeps cells comparable.
#
#   THROUGHPUT ramp (warm steady state, -w5 -runs10):
#     {explore, bi, update} x {1, 4, 8, 16, 32 clients}
#   The mt=1 cell of each use case IS the single-client (latency) point.
#
# Read-only use cases (explore, bi) share one ledger. The Update use case mutates
# its ledger, so each update cell gets its OWN fresh live-created ledger (~5s) for
# a clean R/W starting state.
#
# NOTE: cold-vs-warm cache states are intentionally NOT in this run — Fluree's
# startup preload reads all ledger files (warming the page cache), which confounds
# a naive cold measurement. That needs its own experiment design.
#
# NOT set -e: one bad cell must not abort the matrix.
#
# Usage: ./run-1m-matrix.sh [all|smoke]
#
set -uo pipefail

F="$HOME/db-src/target/release/fluree"
RUNDIR="$HOME/fluree-run"
TOOLS="$HOME/bsbm/bsbmtools-0.2"
TD="$TOOLS/td_1m"
DATASET="$TD/dataset.nt"
UPD="$TOOLS/dataset_update.nt"
HOST="http://localhost:8090"
OUT="$HOME/bsbm/results-1m"
SUMMARY="$OUT/summary.tsv"
RO="mxro:main"
mkdir -p "$OUT"
exec > >(tee -a "$OUT/matrix.log") 2>&1

ONLY="${1:-all}"
say(){ echo "[$(date -u +%H:%M:%S)] $*"; }
health(){ [ "$(curl -s -o /dev/null -w '%{http_code}' "$HOST/health" 2>/dev/null)" = 200 ]; }
ucf(){ case $1 in explore) echo usecases/explore/sparql.txt;; bi) echo usecases/businessIntelligence/sparql.txt;; update) echo usecases/exploreAndUpdate/sparql.txt;; esac; }

ledger_ok(){ # queryable + returns 200?
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$HOST/v1/fluree/query/$1" -H 'Content-Type: application/sparql-query' --data 'SELECT (COUNT(*) AS ?c){?s ?p ?o}' 2>/dev/null)" = 200 ]
}
create_live(){ # create a ledger against the running server and wait until queryable
  (cd "$RUNDIR" && "$F" create "$1" --from "$DATASET" >/dev/null 2>&1) && say "created $1" || say "create $1 (exists/failed)"
  for i in $(seq 1 60); do ledger_ok "$1" && return 0; sleep 1; done
  say "WARN: $1 not queryable after create"; return 1
}

# cell <tag> <usecase> <ledger> <clients> <warmup> <runs>
cell(){
  local tag=$1 uc=$2 ledger=$3 mt=$4 w=$5 runs=$6
  local xml="$OUT/$tag.xml"
  local args=(-idir "$TD" -ucf "$(ucf "$uc")" -w "$w" -runs "$runs" -o "$xml")
  [ "$mt" != 1 ] && args+=(-mt "$mt")
  [ "$uc" = update ] && args+=(-u "$HOST/v1/fluree/update/$ledger" -uqp update -udataset "$UPD")
  say "CELL $tag  (uc=$uc ledger=$ledger mt=$mt w=$w runs=$runs)"
  ( cd "$TOOLS" && timeout 1800 ./testdriver "${args[@]}" "$HOST/v1/fluree/query/$ledger" ) >"$OUT/$tag.log" 2>&1
  local rc=$? qmph tot to
  qmph=$(grep -oP '(?<=<qmph>)[^<]+' "$xml" 2>/dev/null | head -1)
  tot=$(grep -oP '(?<=<totalruntime>)[^<]+' "$xml" 2>/dev/null | head -1)
  to=$(grep -oP '(?<=<timeoutcount>)[^<]+' "$xml" 2>/dev/null | paste -sd+ - | bc 2>/dev/null)
  printf '%s\t%s\t%s\t%s\t%s\t%s\trc=%s\n' "$tag" "$uc" "$mt" "${qmph:-ERR}" "${tot:-}" "${to:-}" "$rc" >> "$SUMMARY"
  say "  -> qmph=${qmph:-ERR} totalruntime=${tot:-} timeouts=${to:-} rc=$rc"
}

health || { say "FATAL: server not up at $HOST"; exit 1; }
[ -f "$SUMMARY" ] || printf 'tag\tusecase\tclients\tqmph\ttotalruntime\ttimeouts\tstatus\n' > "$SUMMARY"
ledger_ok "$RO" || create_live "$RO"

if [ "$ONLY" = smoke ]; then
  say "SMOKE: explore mt=1 and mt=4"
  cell "smoke__explore__c1" explore "$RO" 1 2 3
  cell "smoke__explore__c4" explore "$RO" 4 2 3
  say "SMOKE DONE"; exit 0
fi

say "===== BSBM 1M THROUGHPUT MATRIX START ====="
for uc in explore bi update; do
  for mt in 1 4 8 16 32; do
    if [ "$uc" = update ]; then L="mxu_c${mt}:main"; create_live "$L"; else L="$RO"; fi
    cell "tp__${uc}__c${mt}" "$uc" "$L" "$mt" 5 10
  done
done
say "===== BSBM 1M THROUGHPUT MATRIX DONE ====="
say "summary: $SUMMARY"
