#!/usr/bin/env bash
# Load one scale into a fresh, dedicated Virtuoso instance; fail on input/count drift.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCALE="${1:?usage: load-virtuoso.sh 1m|100m|200m [expected-count]}"
VIRTUOSO_HOME="${VIRTUOSO_HOME:-$HOME/bsbm-engines/virtuoso}"
DATA="${BSBM_DATA:-$SCRIPT_DIR/../datasets/bsbm-$SCALE/td}"
DATA="$(cd "$DATA" && pwd)"
GRAPH="${BSBM_GRAPH:-http://bsbm.org/}"
ENDPOINT="http://127.0.0.1:${HTTP_PORT:-8182}/sparql"
OUT="$VIRTUOSO_HOME/metadata/load-$SCALE";mkdir -p "$OUT"
EXPECTED=$(python3 "$SCRIPT_DIR/check-dataset.py" "$SCALE" "$DATA/dataset.nt" --output "$OUT/dataset.json")
[[ -z ${2:-} || $2 == "$EXPECTED" ]] || { echo 'Expected count conflicts with dataset pin' >&2;exit 1; }
python3 "$SCRIPT_DIR/check-count.py" "$ENDPOINT" 0 --graph "$GRAPH" --output "$OUT/count-before.xml"
isql() { "$VIRTUOSO_HOME/bin/isql" "${SQL_PORT:-1111}" dba dba VERBOSE=OFF; }
# The five datatypes emitted by NTriples.java. USD first appears much later than
# the product/type prefix; register it before concurrent loaders encounter it.
isql > "$OUT/datatype-prime.log" 2>&1 <<'SQL'
SPARQL INSERT DATA { GRAPH <urn:bsbm:datatype-prime> { <urn:prime:s> <urn:prime:p1> "1"^^<http://www.w3.org/2001/XMLSchema#integer>; <urn:prime:p2> "s"^^<http://www.w3.org/2001/XMLSchema#string>; <urn:prime:p3> "2000-01-01"^^<http://www.w3.org/2001/XMLSchema#date>; <urn:prime:p4> "2000-01-01T00:00:00"^^<http://www.w3.org/2001/XMLSchema#dateTime>; <urn:prime:p5> "1.00"^^<http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/vocabulary/USD> } };
SPARQL CLEAR GRAPH <urn:bsbm:datatype-prime>;
checkpoint;
SQL
if grep -q '\*\*\* Error' "$OUT/datatype-prime.log";then cat "$OUT/datatype-prime.log";exit 1;fi
CHUNKS="$DATA/virtuoso-chunks"
[[ ! -e "$CHUNKS" ]] || { echo "Chunk directory already exists: $CHUNKS" >&2;exit 1; }
mkdir "$CHUNKS"
split -n l/16 -d --additional-suffix=.nt "$DATA/dataset.nt" "$CHUNKS/part_"
# Quote SQL string literals, including paths containing apostrophes.
python3 - "$CHUNKS" "$GRAPH" > "$OUT/register.sql" <<'PY'
import sys
q=lambda s:"'"+s.replace("'","''")+"'"
print(f"ld_dir({q(sys.argv[1])}, '*.nt', {q(sys.argv[2])});")
PY
isql < "$OUT/register.sql" > "$OUT/register.log" 2>&1
if grep -q '\*\*\* Error' "$OUT/register.log";then cat "$OUT/register.log";exit 1;fi
loaders=16;[[ "$SCALE" != 200m ]] || loaders=1
echo "$loaders" > "$OUT/load-concurrency.txt"
pids=()
for i in $(seq 1 "$loaders");do printf 'rdf_loader_run();\n' | isql > "$OUT/loader-$i.log" 2>&1 & pids+=("$!");done
for pid in "${pids[@]}";do wait "$pid";done
# A bounded serial retry of explicitly failed chunks; one SQL statement per line.
isql > "$OUT/retry.log" 2>&1 <<'SQL'
SELECT ll_file, ll_error FROM DB.DBA.load_list WHERE ll_error IS NOT NULL;
UPDATE DB.DBA.load_list SET ll_state=0, ll_error=NULL WHERE ll_error IS NOT NULL;
rdf_loader_run();
checkpoint;
SELECT ll_file, ll_error FROM DB.DBA.load_list WHERE ll_error IS NOT NULL;
SQL
if grep -q '\*\*\* Error' "$OUT/retry.log";then cat "$OUT/retry.log";exit 1;fi
python3 "$SCRIPT_DIR/check-count.py" "$ENDPOINT" "$EXPECTED" --graph "$GRAPH" --output "$OUT/count-after.xml"
python3 - "$GRAPH" > "$OUT/update-permissions.sql" <<'PY'
import sys
q="'"+sys.argv[1].replace("'","''")+"'"
print('GRANT SPARQL_UPDATE TO "SPARQL";')
print(f"DB.DBA.RDF_GRAPH_USER_PERMS_SET ({q}, 'SPARQL', 3);")
print('checkpoint;')
PY
isql < "$OUT/update-permissions.sql" > "$OUT/update-permissions.log" 2>&1
if grep -q '\*\*\* Error' "$OUT/update-permissions.log";then cat "$OUT/update-permissions.log";exit 1;fi
printf '%s\n' "$GRAPH" > "$OUT/graph.txt"
echo "Ready: $ENDPOINT (driver -dg $GRAPH)"
