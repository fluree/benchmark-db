#!/usr/bin/env bash
#
# BSBM throughput matrix at a larger scale (100M / 200M) against Fluree.
# Explore + BI ramps only — Update is omitted at scale (multi-client update is
# blocked by the concurrent-write bug; see bsbm-fluree-concurrent-update-bugs.md).
#
# Assumes the server is already up with the scale ledger loaded (see the runbook
# in the session). Server stays up; no restarts.
#
# Usage: ./run-scale-matrix.sh <100m|200m>
#
set -uo pipefail
SCALE="${1:?usage: run-scale-matrix.sh <100m|200m>}"
F="$HOME/db-src/target/release/fluree"
TOOLS="$HOME/bsbm/bsbmtools-0.2"
TD="$TOOLS/td_${SCALE}"
case "$SCALE" in
  100m) LEDGER="bsbm100:main" ;;
  200m) LEDGER="bsbm200:main" ;;
  *) echo "bad scale: $SCALE"; exit 1 ;;
esac
HOST="http://localhost:8090"
OUT="$HOME/bsbm/results-${SCALE}"
SUMMARY="$OUT/summary.tsv"
mkdir -p "$OUT"
say(){ echo "[$(date -u +%H:%M:%S)] $*"; }
ucf(){ case $1 in explore) echo usecases/explore/sparql.txt;; bi) echo usecases/businessIntelligence/sparql.txt;; esac; }

# cell <tag> <usecase> <clients> <warmup> <runs>
cell(){
  local tag=$1 uc=$2 mt=$3 w=$4 runs=$5 xml="$OUT/$1.xml"
  local args=(-idir "$TD" -ucf "$(ucf "$uc")" -w "$w" -runs "$runs" -t 300000 -o "$xml")
  [ "$mt" != 1 ] && args+=(-mt "$mt")
  say "CELL $tag (uc=$uc mt=$mt w=$w runs=$runs)"
  ( cd "$TOOLS" && timeout 5400 ./testdriver "${args[@]}" "$HOST/v1/fluree/query/$LEDGER" ) >"$OUT/$tag.log" 2>&1
  local rc=$? qmph tot to
  qmph=$(grep -oP '(?<=<qmph>)[^<]+' "$xml" 2>/dev/null | head -1)
  tot=$(grep -oP '(?<=<totalruntime>)[^<]+' "$xml" 2>/dev/null | head -1)
  to=$(grep -oP '(?<=<timeoutcount>)[^<]+' "$xml" 2>/dev/null | paste -sd+ - | bc 2>/dev/null)
  printf '%s\t%s\t%s\t%s\t%s\t%s\trc=%s\n' "$tag" "$uc" "$mt" "${qmph:-ERR}" "${tot:-}" "${to:-}" "$rc" >> "$SUMMARY"
  say "  -> qmph=${qmph:-ERR} totalruntime=${tot:-} timeouts=${to:-} rc=$rc"
}

[ "$(curl -s -o /dev/null -w '%{http_code}' "$HOST/v1/fluree/query/$LEDGER" -H 'Content-Type: application/sparql-query' --data 'SELECT (COUNT(*) AS ?c){?s ?p ?o}')" = 200 ] || { say "FATAL: $LEDGER not queryable"; exit 1; }
[ -f "$SUMMARY" ] || printf 'tag\tusecase\tclients\tqmph\ttotalruntime\ttimeouts\tstatus\n' > "$SUMMARY"

say "===== BSBM $SCALE MATRIX (explore + bi) START ====="
for uc in explore bi; do
  for mt in 1 4 8 16 32; do
    cell "tp__${uc}__c${mt}" "$uc" "$mt" 5 10
  done
done
say "===== BSBM $SCALE MATRIX DONE ====="
