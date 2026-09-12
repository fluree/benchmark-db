#!/bin/bash
# Pokec benchgraph, 4 engines x 3 scales, clean protocol:
#   fresh load -> reads1 (discarded warmup) -> reads2 (canonical reads) -> full (canonical writes)
# Every engine per-commit durable, official images with --network host, one persistent client
# connection per engine. Produces <scale>_<engine>_{reads1,reads2,full}.tsv under $OUT; merge with
# merge_runs.py, then gen_report.py.
#
# Env: FBIN (fluree binary), SCALES, ENGINES, OUT.  Requires docker, python3 neo4j + falkordb +
# falkordb-bulk-loader, and the datasets under DATA (default: this script's data/ directory).
# Use a disposable benchmark host: this script recreates its named stores and containers.
RUN=${RUN:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
OUT=${OUT:-$RUN/results/run}
DATA=${DATA:-$RUN/data}
mkdir -p "$OUT"
cd "$HOME"
SCALES="${SCALES:-small medium large}"; ENGINES="${ENGINES:-fluree neo4j memgraph falkordb}"
declare -A NV=( [small]=10000 [medium]=100000 [large]=1632803 )
declare -A RUNS=( [small]=5 [medium]=5 [large]=3 ); declare -A WARM=( [small]=2 [medium]=2 [large]=1 )
FBIN=${FBIN:-$HOME/fluree-src/target/release/fluree}
NEO4J_IMAGE=${NEO4J_IMAGE:-neo4j:5.26-community}
FALKORDB_IMAGE=${FALKORDB_IMAGE:-falkordb/falkordb:latest}
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a $OUT/run.log; }
src_for(){ [[ $1 == large ]] && echo $DATA/pokec_large.setup.cypher || echo $DATA/pokec_${1}_import.cypher; }
runner(){ # scale engine name extra-args...
  local s=$1 e=$2 n=$3; shift 3
  python3 $RUN/bench_runner.py --engine $e --num-vertices ${NV[$s]} --seed 42 --warmup ${WARM[$s]} --runs ${RUNS[$s]} \
    --queryset $RUN/query-set.tsv --params-file $RUN/params_$s.json "$@" --output $OUT/${s}_${n}.tsv > $OUT/${s}_${n}.log 2>&1 || { cat "$OUT/${s}_${n}.log"; exit 1; }
  tail -1 $OUT/${s}_${n}.log | tee -a $OUT/run.log
}
passes(){ # scale engine extra-args...   -> reads1, reads2, full
  local s=$1 e=$2; shift 2
  runner $s $e ${e}_reads1 --skip-writes "$@"; runner $s $e ${e}_reads2 --skip-writes "$@"; runner $s $e ${e}_full "$@"
}
csvs(){ # scale -> $OUT/csv/$scale/{User,Friend}.csv (+ neo4j-typed headers)
  local s=$1 d=$OUT/csv/$s; [[ -s $d/Friend.csv ]] && return; mkdir -p $d
  python3 $RUN/cypher_to_csv.py $(src_for $s) $d/User.csv $d/Friend.csv | tee -a $OUT/run.log
  { echo "id:ID,completion_percentage:int,gender,age:int"; tail -n +2 $d/User.csv; } > $d/User.neo4j.csv
  { echo ":START_ID,:END_ID"; tail -n +2 $d/Friend.csv; } > $d/Friend.neo4j.csv
}
fluree_count(){ curl -s -X POST http://127.0.0.1:8090/v1/fluree/query/pokec:main -H 'Content-Type: application/cypher' -d '{"cypher":"MATCH (n:User) RETURN count(n)","params":{}}' | head -c 200; }

do_fluree(){ local s=$1; log "== fluree $s"; pkill -f "fluree server ru[n]"; sleep 2
  local d=~/pokec/v421-fluree-$s; rm -rf $d; mkdir -p $d; cd $d
  export FLUREE_CYPHER_ALLOW_FULL_SCAN=1 FLUREE_STORAGE_FSYNC=wal; unset FLUREE_REINDEX_MIN_BYTES
  $FBIN init >/dev/null; local t0=$SECONDS; $FBIN create pokec --from $(src_for $s) > $OUT/${s}_fluree_import.log 2>&1
  log "fluree import ${s}: $((SECONDS-t0))s $(grep -i imported $OUT/${s}_fluree_import.log | tail -1)"; sync
  nohup $FBIN server run --listen-addr 127.0.0.1:8090 > $OUT/${s}_fluree_server.log 2>&1 &
  local pid=$!; for i in $(seq 1 120); do curl -sf -o /dev/null http://127.0.0.1:8090/health && break; sleep 2; done
  log "fluree $s users: $(fluree_count)"
  passes $s fluree --http-port 8090
  kill -15 $pid; sleep 3; cd ~; log "DONE fluree $s"
}
do_neo4j(){ local s=$1; log "== neo4j $s"; csvs $s
  sudo docker rm -f neo4j >/dev/null 2>&1; sudo docker volume rm -f neo4jdata >/dev/null 2>&1
  local t0=$SECONDS
  sudo docker run --rm -v neo4jdata:/data -v $OUT/csv/$s:/import "$NEO4J_IMAGE" \
    neo4j-admin database import full neo4j --id-type=INTEGER --nodes=User=/import/User.neo4j.csv --relationships=Friend=/import/Friend.neo4j.csv > $OUT/${s}_neo4j_import.log 2>&1
  log "neo4j admin import ${s}: $((SECONDS-t0))s $(grep -E "IMPORT DONE|nodes|relationships" $OUT/${s}_neo4j_import.log | tail -3 | tr '\n' ' ')"
  sudo docker run -d --name neo4j --network host -v neo4jdata:/data --env NEO4J_AUTH=neo4j/benchpass \
    --env NEO4J_server_memory_heap_max__size=8G --env NEO4J_server_memory_pagecache_size=8G "$NEO4J_IMAGE" >/dev/null
  for i in $(seq 1 90); do sudo docker exec neo4j cypher-shell -u neo4j -p benchpass "RETURN 1" >/dev/null 2>&1 && break; sleep 3; done
  sudo docker exec neo4j cypher-shell -u neo4j -p benchpass "CREATE INDEX user_id IF NOT EXISTS FOR (u:User) ON (u.id)" >/dev/null 2>&1
  sudo docker exec neo4j cypher-shell -u neo4j -p benchpass "CALL db.awaitIndexes(600)" >/dev/null 2>&1
  log "neo4j $s users: $(sudo docker exec neo4j cypher-shell -u neo4j -p benchpass 'MATCH (n:User) RETURN count(*)' | tail -1) edges: $(sudo docker exec neo4j cypher-shell -u neo4j -p benchpass 'MATCH ()-[r]->() RETURN count(r)' | tail -1)"
  passes $s neo4j --bolt-port 7687
  sudo docker rm -f neo4j >/dev/null 2>&1; log "DONE neo4j $s"
}
do_memgraph(){ local s=$1; log "== memgraph $s"
  sudo docker rm -f memgraph >/dev/null 2>&1; sudo docker volume rm -f mgdata >/dev/null 2>&1
  sudo docker run -d --name memgraph --network host -v mgdata:/var/lib/memgraph memgraph/memgraph:3.11.0 --telemetry-enabled=False --storage-snapshot-on-exit=true >/dev/null
  sleep 8; echo "CREATE INDEX ON :User(id);" | sudo docker exec -i memgraph mgconsole >/dev/null 2>&1
  local t0=$SECONDS; sudo docker exec -i memgraph mgconsole < $(src_for $s) > $OUT/${s}_memgraph_import.log 2>&1
  log "memgraph load ${s}: $((SECONDS-t0))s"
  echo "CREATE SNAPSHOT;" | sudo docker exec -i memgraph mgconsole >/dev/null 2>&1
  sudo docker stop -t 600 memgraph >/dev/null; sudo docker rm memgraph >/dev/null
  sudo docker run -d --name memgraph --network host -v mgdata:/var/lib/memgraph memgraph/memgraph:3.11.0 --telemetry-enabled=False --data-recovery-on-startup=true --storage-wal-file-flush-every-n-tx=1 >/dev/null
  for i in $(seq 1 300); do echo "RETURN 1;" | sudo docker exec -i memgraph mgconsole >/dev/null 2>&1 && break; sleep 2; done
  log "memgraph $s users: $(echo 'MATCH (n:User) RETURN count(*);' | sudo docker exec -i memgraph mgconsole 2>/dev/null | tail -2 | head -1) edges: $(echo 'MATCH ()-[r]->() RETURN count(r);' | sudo docker exec -i memgraph mgconsole 2>/dev/null | tail -2 | head -1)"
  passes $s memgraph --bolt-port 7687
  sudo docker rm -f memgraph >/dev/null 2>&1; log "DONE memgraph $s"
}
do_falkordb(){ local s=$1; log "== falkordb $s"; csvs $s
  sudo docker rm -f falkor >/dev/null 2>&1; sudo docker volume rm -f falkordata >/dev/null 2>&1
  sudo docker run -d --name falkor --network host -v falkordata:/var/lib/falkordb/data -e FALKORDB_ARGS="RESULTSET_SIZE -1 TIMEOUT 0" "$FALKORDB_IMAGE" >/dev/null
  for i in $(seq 1 60); do sudo docker exec falkor redis-cli ping 2>/dev/null | grep -q PONG && break; sleep 1; done
  sudo docker exec falkor redis-cli GRAPH.CONFIG SET RESULTSET_SIZE -1 >/dev/null; sudo docker exec falkor redis-cli GRAPH.CONFIG SET TIMEOUT 0 >/dev/null
  log "falkordb config: $(sudo docker exec falkor redis-cli GRAPH.CONFIG GET RESULTSET_SIZE | tr "\n" " ") $(sudo docker exec falkor redis-cli GRAPH.CONFIG GET TIMEOUT | tr "\n" " ")"
  local t0=$SECONDS
  falkordb-bulk-insert pokec --nodes-with-label User $OUT/csv/$s/User.csv --relations-with-type Friend $OUT/csv/$s/Friend.csv --id-type INTEGER > $OUT/${s}_falkordb_import.log 2>&1
  log "falkordb bulk load ${s}: $((SECONDS-t0))s $(tail -2 $OUT/${s}_falkordb_import.log | tr '\n' ' ')"
  sudo docker exec falkor redis-cli GRAPH.QUERY pokec "CREATE INDEX FOR (u:User) ON (u.id)" >/dev/null
  # Index construction is async and takes minutes on the 1.6 M-node graph; the query plan is
  # the only reliable signal (measuring too early silently benchmarks a label scan).
  for i in $(seq 1 300); do
    sudo docker exec falkor redis-cli GRAPH.EXPLAIN pokec "MATCH (n:User {id: 1}) RETURN n" | grep -q "Index Scan" && break
    sleep 2
  done
  log "falkordb $s plan: $(sudo docker exec falkor redis-cli GRAPH.EXPLAIN pokec 'MATCH (n:User {id: 1}) RETURN n' | tr '\n' ' ')"
  if ! sudo docker exec falkor redis-cli GRAPH.EXPLAIN pokec "MATCH (n:User {id: 1}) RETURN n" | grep -q "Index Scan"; then
    log "FATAL: falkordb $s index never built; skipping"
    sudo docker rm -f falkor >/dev/null 2>&1
    return 1
  fi
  sudo docker exec falkor redis-cli CONFIG SET appendonly yes >/dev/null; sudo docker exec falkor redis-cli CONFIG SET appendfsync always >/dev/null
  for i in $(seq 1 600); do sudo docker exec falkor redis-cli INFO persistence | grep -q "aof_rewrite_in_progress:0" && sudo docker exec falkor redis-cli INFO persistence | grep -q "aof_enabled:1" && break; sleep 2; done
  log "falkordb $s: $(sudo docker exec falkor redis-cli CONFIG GET appendfsync | tr '\n' ' ') $(sudo docker exec falkor redis-cli INFO persistence | grep -E 'aof_enabled|aof_rewrite_in_progress' | tr '\n' ' ') users: $(sudo docker exec falkor redis-cli GRAPH.QUERY pokec 'MATCH (n:User) RETURN count(n)' | sed -n 3p) edges: $(sudo docker exec falkor redis-cli GRAPH.QUERY pokec 'MATCH ()-[r]->() RETURN count(r)' | sed -n 3p)"
  passes $s falkordb --redis-port 6379 --graph pokec
  sudo docker rm -f falkor >/dev/null 2>&1; log "DONE falkordb $s"
}
for s in $SCALES; do
  [[ -s $(src_for $s) ]] || { log "missing dataset for $s"; continue; }
  for e in $ENGINES; do
    if grep -q "^=== $e: 35 ok" $OUT/${s}_${e}_full.log 2>/dev/null && [[ -s $OUT/${s}_${e}_reads2.tsv ]]; then log "skip $e $s (done)"; continue; fi
    do_$e $s
  done
done
log "V421-RUN-DONE"
