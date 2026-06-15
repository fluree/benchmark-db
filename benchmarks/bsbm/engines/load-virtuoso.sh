#!/usr/bin/env bash
#
# Bulk-load one BSBM scale into Virtuoso, into a per-scale named graph
# http://bsbm.org/<scale>. A single .nt file loads single-threaded, so we split
# it into 16 line-aligned chunks and run 16 parallel rdf_loader_run().
#
# Usage: ./load-virtuoso.sh <1m|100m|200m> <expected_triple_count>
#   e.g. ./load-virtuoso.sh 100m 100000748
#
set -uo pipefail
SCALE="${1:?usage: load-virtuoso.sh <scale> <expected_count>}"
EXP="${2:?expected count}"
DIR="${BSBM_TOOLS:-$HOME/bsbm/bsbmtools-0.2}/td_${SCALE}"
GRAPH="http://bsbm.org/${SCALE}"
CH="$DIR/chunks"; N=16
say(){ echo "[$(date -u +%H:%M:%S)] $*"; }
isql(){ isql-vt 1111 dba dba; }

rm -rf "$CH"; mkdir -p "$CH"
say "splitting $(du -h "$DIR/dataset.nt"|cut -f1) into $N chunks..."
split -n l/$N -d --additional-suffix=.nt "$DIR/dataset.nt" "$CH/part_"
say "registering ($(ls "$CH"/*.nt|wc -l) files)..."
printf "ld_dir('%s', '*.nt', '%s');\nSELECT count(*) FROM DB.DBA.load_list WHERE ll_state=0 AND ll_graph='%s';\n" \
  "$CH" "$GRAPH" "$GRAPH" | isql 2>&1 | grep -A2 '^count' | tail -1
say "loading ($N parallel loaders)..."
for i in $(seq 1 $N); do echo "rdf_loader_run();" | isql >/tmp/loader_${SCALE}_$i.log 2>&1 & done
wait
echo "checkpoint;" | isql >/dev/null 2>&1
ERR=$(echo "SELECT count(*) FROM DB.DBA.load_list WHERE ll_error IS NOT NULL AND ll_graph='$GRAPH';" | isql 2>&1 | grep -oE '^[0-9]+' | head -1)
CNT=$(echo "SPARQL SELECT (COUNT(*) AS ?c) FROM <$GRAPH> WHERE {?s ?p ?o};" | isql 2>&1 | grep -oE '^[0-9]{4,}' | head -1)
say "errors=$ERR  count=$CNT  (expected $EXP)"
rm -rf "$CH"
[ "$CNT" = "$EXP" ] && say "DONE $SCALE OK" || say "WARN: count mismatch"
