#!/bin/bash
# Durability verification for the v4.2.1 Pokec run: count fsync-family syscalls per engine over an
# identical 40-write pass (8 write queries x 5 runs) on pokec small, in the exact configuration
# the benchmark measures. Also counts the shipped defaults of Memgraph and FalkorDB for contrast.
RUN=${RUN:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
OUT=${OUT:-$RUN/results/run}
DATA=${DATA:-$RUN/data}
mkdir -p "$OUT"
cd "$HOME"
FBIN=${FBIN:-$HOME/fluree-src/target/release/fluree}
NEO4J_IMAGE=${NEO4J_IMAGE:-neo4j:5.26-community}
FALKORDB_IMAGE=${FALKORDB_IMAGE:-falkordb/falkordb:latest}
R="python3 $RUN/bench_runner.py --num-vertices 10000 --seed 42 --warmup 0 --runs 5 --queryset $OUT/writes.tsv --params-file $RUN/params_small.json"
grep -P "^query_id|\twrite\t" $RUN/query-set.tsv > $OUT/writes.tsv
trace() { # name pid engine-args...
  local name=$1 pid=$2; shift 2
  sudo strace -f --seccomp-bpf -c -e trace=fsync,fdatasync,sync_file_range,syncfs -p $pid -o $OUT/dur_$name.strace >/dev/null 2>&1 &
  local sp=$!; sleep 2
  local result=0
  $R "$@" --output $OUT/dur_$name.tsv > $OUT/dur_$name.log 2>&1 || result=$?
  sudo kill -INT $sp 2>/dev/null; sleep 3
  [[ $result == 0 ]] || { cat "$OUT/dur_$name.log"; exit "$result"; }
  echo "== $name: $(grep -c . $OUT/dur_$name.tsv) rows; $(grep -E 'fsync|fdatasync|sync_file|syncfs' $OUT/dur_$name.strace | awk '{print $NF": "$(NF-1)}' | tr '\n' ' ')"
}
# Fluree v4.2.1, FLUREE_STORAGE_FSYNC=wal (as measured)
pkill -f "fluree server ru[n]"; sleep 2; rm -rf ~/pokec/dur-fluree; mkdir -p ~/pokec/dur-fluree; cd ~/pokec/dur-fluree
export FLUREE_CYPHER_ALLOW_FULL_SCAN=1 FLUREE_STORAGE_FSYNC=wal; unset FLUREE_REINDEX_MIN_BYTES
$FBIN init >/dev/null; $FBIN create pokec --from $DATA/pokec_small_import.cypher >/dev/null 2>&1; sync
nohup $FBIN server run --listen-addr 127.0.0.1:8090 > /dev/null 2>&1 &
fpid=$!; for i in $(seq 1 60); do curl -sf -o /dev/null http://127.0.0.1:8090/health && break; sleep 1; done
trace fluree $fpid --engine fluree --http-port 8090
kill -15 $fpid; sleep 2; cd ~
# Rebuild the small CSVs and Neo4j store; the performance run may have ended at large.
mkdir -p "$OUT/csv/small"
python3 "$RUN/cypher_to_csv.py" "$DATA/pokec_small_import.cypher" \
  "$OUT/csv/small/User.csv" "$OUT/csv/small/Friend.csv" || exit 1
{ echo "id:ID,completion_percentage:int,gender,age:int"; tail -n +2 "$OUT/csv/small/User.csv"; } > "$OUT/csv/small/User.neo4j.csv"
{ echo ":START_ID,:END_ID"; tail -n +2 "$OUT/csv/small/Friend.csv"; } > "$OUT/csv/small/Friend.neo4j.csv"
# Neo4j (durable by default), fresh small graph in a dedicated diagnostic volume.
sudo docker rm -f neo4j >/dev/null 2>&1
sudo docker volume rm -f neodur >/dev/null 2>&1
sudo docker run --rm -v neodur:/data -v "$OUT/csv/small:/import" "$NEO4J_IMAGE" \
  neo4j-admin database import full neo4j --id-type=INTEGER \
  --nodes=User=/import/User.neo4j.csv --relationships=Friend=/import/Friend.neo4j.csv || exit 1
sudo docker run -d --name neo4j --network host -v neodur:/data --env NEO4J_AUTH=neo4j/benchpass "$NEO4J_IMAGE" >/dev/null
for i in $(seq 1 90); do sudo docker exec neo4j cypher-shell -u neo4j -p benchpass "RETURN 1" >/dev/null 2>&1 && break; sleep 3; done
sudo docker exec neo4j cypher-shell -u neo4j -p benchpass "CREATE INDEX user_id IF NOT EXISTS FOR (u:User) ON (u.id)" >/dev/null
sudo docker exec neo4j cypher-shell -u neo4j -p benchpass "CALL db.awaitIndexes(600)" >/dev/null
trace neo4j $(pgrep -f "org.neo4j.server.CommunityEntryPoint" | head -1) --engine neo4j --bolt-port 7687
sudo docker rm -f neo4j >/dev/null 2>&1
# Memgraph: measured config (flush every tx) and shipped default
for cfg in fsync default; do
  extra=""; [[ $cfg == fsync ]] && extra="--storage-wal-file-flush-every-n-tx=1"
  sudo docker rm -f memgraph >/dev/null 2>&1; sudo docker volume rm -f mgdur >/dev/null 2>&1
  sudo docker run -d --name memgraph --network host -v mgdur:/var/lib/memgraph memgraph/memgraph:3.11.0 --telemetry-enabled=False $extra >/dev/null
  sleep 8; echo "CREATE INDEX ON :User(id);" | sudo docker exec -i memgraph mgconsole >/dev/null 2>&1
  sudo docker exec -i memgraph mgconsole < $DATA/pokec_small_import.cypher >/dev/null 2>&1
  trace memgraph-$cfg $(pgrep -x memgraph | head -1) --engine memgraph --bolt-port 7687
  sudo docker rm -f memgraph >/dev/null 2>&1
done
# FalkorDB: measured config (AOF always) and shipped default
for cfg in aof default; do
  sudo docker rm -f falkor >/dev/null 2>&1; sudo docker volume rm -f fdur >/dev/null 2>&1
  sudo docker run -d --name falkor --network host -v fdur:/var/lib/falkordb/data "$FALKORDB_IMAGE" >/dev/null
  for i in $(seq 1 60); do sudo docker exec falkor redis-cli ping 2>/dev/null | grep -q PONG && break; sleep 1; done
  falkordb-bulk-insert pokec --nodes-with-label User $OUT/csv/small/User.csv --relations-with-type Friend $OUT/csv/small/Friend.csv --id-type INTEGER >/dev/null 2>&1
  sudo docker exec falkor redis-cli GRAPH.QUERY pokec "CREATE INDEX FOR (u:User) ON (u.id)" >/dev/null; sleep 3
  if [[ $cfg == aof ]]; then
    sudo docker exec falkor redis-cli CONFIG SET appendonly yes >/dev/null; sudo docker exec falkor redis-cli CONFIG SET appendfsync always >/dev/null
    for i in $(seq 1 120); do sudo docker exec falkor redis-cli INFO persistence | grep -q "aof_enabled:1" && break; sleep 1; done
  fi
  echo "   falkor-$cfg: $(sudo docker exec falkor redis-cli CONFIG GET appendonly | tr '\n' ' ')$(sudo docker exec falkor redis-cli CONFIG GET appendfsync | tr '\n' ' ')"
  trace falkordb-$cfg $(pgrep -f "redis-server" | head -1) --engine falkordb --redis-port 6379 --graph pokec
  sudo docker rm -f falkor >/dev/null 2>&1
done
echo DURABILITY2-DONE
