#!/bin/bash
# BSBM 100M relational baseline: MySQL 8.0 (Ubuntu 24.04 apt) server or generator. Same pinned toolkit and
# generator invocation as the Fluree runs, but -s sql (BSBM's own MySQL schema + indexes). Arg: server|generator
set -euo pipefail
exec > >(tee -a ~/setup.log) 2>&1
trap 'r=$?; if [[ $r != 0 ]]; then echo $r > ~/setup.exit; fi' EXIT
log() { echo "[$(date -u +%H:%M:%S)] $*"; }
role=$1; pc=284826
sudo cloud-init status --wait >/dev/null || true
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq curl unzip python3 openjdk-21-jdk-headless sysstat jq >/dev/null
mkdir -p ~/harness ~/results/cells ~/data
tar -xzf ~/harness.tar.gz -C ~/harness
cd ~/harness/benchmarks/bsbm
echo '40f5e59baadec3af0014b7647989d3e0fc0476af25e84a4bc9d7f8cd81520aaa  bsbmtools-v0.2.zip' | sha256sum -c -
unzip -q -o bsbmtools-v0.2.zip; cd bsbmtools-0.2; chmod +x generate testdriver
python3 ~/patch-driver.py
mkdir -p diagnostic-classes
javac -cp 'lib/*' -d diagnostic-classes src/benchmark/testdriver/NetQuery.java
# SQL explore-select subset (same rule as the SPARQL subset: drop Q9 and Q12)
cp -a queries/sql/explore/sqlQueries queries/sql/explore/sqlQueries-select
python3 - <<'PY'
from pathlib import Path
p=Path('queries/sql/explore/sqlQueries-select/querymix.txt');p.write_text(' '.join(x for x in p.read_text().split() if x not in {'9','12'})+'\n')
PY
mkdir -p usecases/explore-select; echo 'querymix=queries/sql/explore/sqlQueries-select' > usecases/explore-select/sql.txt
log "generating SQL dump"
./generate -fc -pc $pc -s sql -dir "$HOME/data" -fn "$HOME/data/dataset" > ~/results/generate.log 2>&1
( cd ~/data && find . -maxdepth 1 -type f ! -name '*.sql' | sort | xargs sha256sum ) > ~/results/td.sha256
ls -l ~/data/dataset > ~/results/dump-files.txt
log "generated"
if [[ $role == server ]]; then
  sudo apt-get install -y -qq mysql-server >/dev/null
  mysqld --version | tee ~/results/version.txt
  sudo tee /etc/mysql/mysql.conf.d/zz-bsbm.cnf >/dev/null <<'CNF'
[mysqld]
bind-address = 0.0.0.0
skip-name-resolve
disable_log_bin
max_connections = 1000
innodb_buffer_pool_size = 40G
innodb_redo_log_capacity = 8G
innodb_flush_method = O_DIRECT
table_open_cache = 4000
CNF
  sudo systemctl restart mysql
  sudo mysql -e "CREATE DATABASE benchmark; CREATE USER 'bsbm'@'%' IDENTIFIED BY 'bsbm'; GRANT SELECT ON benchmark.* TO 'bsbm'@'%';"
  t0=$SECONDS
  for f in $(ls ~/data/dataset/*.sql | sort); do
    log "load $(basename $f)"; sudo mysql benchmark < $f
  done
  echo $((SECONDS - t0)) > ~/results/load.seconds; log "load: $((SECONDS - t0))s"
  sudo mysql benchmark -e "SHOW TABLES" -N | while read t; do sudo mysql benchmark -N -e "ANALYZE TABLE \`$t\`" >/dev/null; done
  sudo mysql -N -e "SELECT table_name, table_rows, data_length, index_length FROM information_schema.tables WHERE table_schema='benchmark' ORDER BY table_name" > ~/results/tables.tsv
  for t in $(sudo mysql benchmark -N -e "SHOW TABLES"); do echo -e "$t\t$(sudo mysql benchmark -N -e "SELECT COUNT(*) FROM \`$t\`")"; done > ~/results/rowcounts.tsv
  sudo du -sb /var/lib/mysql > ~/results/mysql-bytes.txt
  sudo mysql -e "SHOW VARIABLES" > ~/results/mysql-variables.tsv
  nohup pidstat -h -u -r -C mysqld 10 > ~/results/pidstat.log 2>&1 &
else
  cd ~/harness/benchmarks/bsbm/bsbmtools-0.2
  curl -fsSL -o lib/mysql-connector-j-8.4.0.jar https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar
  sha256sum lib/mysql-connector-j-8.4.0.jar | tee ~/results/connector.sha256
fi
lscpu > ~/results/lscpu.txt; free -b > ~/results/memory.txt; uname -a > ~/results/uname.txt
date -Is > ~/setup.done
log "setup done"
