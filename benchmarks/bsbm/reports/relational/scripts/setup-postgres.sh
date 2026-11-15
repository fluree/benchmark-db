#!/bin/bash
# BSBM 100M relational baseline, PostgreSQL (Ubuntu 24.04 apt = PostgreSQL 16) on the MySQL server host.
# Data: the MySQL tables already loaded from BSBM's own `-s sql` dump, exported with SELECT ... INTO OUTFILE
# (tab-separated, backslash escapes, \N nulls = PostgreSQL COPY text format), so both engines hold identical rows.
# Schema and indexes mirror the MySQL tables exactly (BSBM's indexes + the two link-table indexes added for MySQL).
set -euo pipefail
exec > >(tee -a ~/pgsetup.log) 2>&1
trap 'r=$?; if [[ $r != 0 ]]; then echo $r > ~/pgsetup.exit; fi' EXIT
log() { echo "[$(date -u +%H:%M:%S)] $*"; }
R=~/results-pg; mkdir -p $R; cp ~/results/rowcounts.tsv $R/
TABLES="productfeature producttype producer product producttypeproduct productfeatureproduct vendor offer person review"
M=/var/lib/mysql-files; X=/srv/bsbm-export
rm -f ~/pgsetup.exit
if [[ ! -f $X/review.tsv ]]; then
  log "export from MySQL"
  sudo systemctl start mysql; for i in $(seq 60); do sudo mysql -N -e 'SELECT 1' >/dev/null 2>&1 && break; sleep 1; done
  for t in $TABLES; do sudo test -f $M/$t.tsv || sudo mysql benchmark -e "SELECT * FROM \`$t\` INTO OUTFILE '$M/$t.tsv'"; done
  sudo mkdir -p $X; sudo sh -c "mv $M/*.tsv $X/"; sudo chown -R postgres:postgres $X
  sudo systemctl stop mysql; sudo systemctl disable mysql
fi
sudo ls -l $X | tee $R/export-files.txt
log "install PostgreSQL"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get install -y -qq postgresql >/dev/null
V=$(ls /etc/postgresql); C=/etc/postgresql/$V/main
sudo -u postgres psql -At -c 'SELECT version()' | tee $R/version.txt
sudo tee $C/conf.d/zz-bsbm.conf >/dev/null <<'CNF'
listen_addresses = '*'
max_connections = 300
shared_buffers = 16GB
effective_cache_size = 48GB
work_mem = 32MB
maintenance_work_mem = 4GB
random_page_cost = 1.1
effective_io_concurrency = 200
jit = off
huge_pages = try
max_wal_size = 16GB
checkpoint_timeout = 30min
CNF
sudo grep -q "^host benchmark bsbm" $C/pg_hba.conf || echo "host benchmark bsbm 172.31.0.0/16 scram-sha-256" | sudo tee -a $C/pg_hba.conf >/dev/null
sudo systemctl restart postgresql
sudo -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
DROP DATABASE IF EXISTS benchmark;
DROP USER IF EXISTS bsbm;
CREATE USER bsbm PASSWORD 'bsbm';
CREATE DATABASE benchmark TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C';
SQL
# utf8mb3_bin (byte-order comparison) in MySQL == "C" collation here
sudo -u postgres psql -v ON_ERROR_STOP=1 benchmark <<'SQL'
CREATE TABLE productfeature (nr int NOT NULL, label varchar(100), comment varchar(2000), publisher int, publishDate date);
CREATE TABLE producttype (nr int NOT NULL, label varchar(100), comment varchar(2000), parent int, publisher int, publishDate date);
CREATE TABLE producer (nr int NOT NULL, label varchar(100), comment varchar(2000), homepage varchar(100), country char(2), publisher int, publishDate date);
CREATE TABLE product (nr int NOT NULL, label varchar(100), comment varchar(2000), producer int,
  propertyNum1 int, propertyNum2 int, propertyNum3 int, propertyNum4 int, propertyNum5 int, propertyNum6 int,
  propertyTex1 varchar(250), propertyTex2 varchar(250), propertyTex3 varchar(250), propertyTex4 varchar(250), propertyTex5 varchar(250), propertyTex6 varchar(250),
  publisher int, publishDate date);
CREATE TABLE producttypeproduct (product int NOT NULL, productType int NOT NULL);
CREATE TABLE productfeatureproduct (product int NOT NULL, productFeature int NOT NULL);
CREATE TABLE vendor (nr int NOT NULL, label varchar(100), comment varchar(2000), homepage varchar(100), country char(2), publisher int, publishDate date);
CREATE TABLE offer (nr int NOT NULL, product int, producer int, vendor int, price double precision, validFrom timestamp, validTo timestamp,
  deliveryDays int, offerWebpage varchar(100), publisher int, publishDate date);
CREATE TABLE person (nr int NOT NULL, name varchar(30), mbox_sha1sum char(40), country char(2), publisher int, publishDate date);
CREATE TABLE review (nr int NOT NULL, product int, producer int, person int, reviewDate timestamp, title varchar(200), text text,
  language char(2), rating1 int, rating2 int, rating3 int, rating4 int, publisher int, publishDate date);
SQL
log "load"
t0=$SECONDS
for t in $TABLES; do sudo -u postgres psql -v ON_ERROR_STOP=1 benchmark -c "COPY $t FROM '$X/$t.tsv'"; done
log "indexes"
sudo -u postgres psql -v ON_ERROR_STOP=1 benchmark <<'SQL'
ALTER TABLE productfeature ADD PRIMARY KEY (nr);
ALTER TABLE producttype ADD PRIMARY KEY (nr);
ALTER TABLE producer ADD PRIMARY KEY (nr);
ALTER TABLE product ADD PRIMARY KEY (nr);
CREATE INDEX product_producer ON product (producer);
ALTER TABLE producttypeproduct ADD PRIMARY KEY (product, productType);
CREATE INDEX ptp_type ON producttypeproduct (productType, product);
ALTER TABLE productfeatureproduct ADD PRIMARY KEY (product, productFeature);
CREATE INDEX pfp_feature ON productfeatureproduct (productFeature, product);
ALTER TABLE vendor ADD PRIMARY KEY (nr);
ALTER TABLE offer ADD PRIMARY KEY (nr);
CREATE INDEX offer_product ON offer (product);
CREATE INDEX offer_vendor ON offer (vendor);
ALTER TABLE person ADD PRIMARY KEY (nr);
ALTER TABLE review ADD PRIMARY KEY (nr);
CREATE INDEX review_product ON review (product);
CREATE INDEX review_person ON review (person);
GRANT SELECT ON ALL TABLES IN SCHEMA public TO bsbm;
SQL
sudo -u postgres vacuumdb --analyze --jobs 8 benchmark
echo $((SECONDS - t0)) > $R/load.seconds; log "load+index+vacuum: $((SECONDS - t0))s"
for t in $TABLES; do echo -e "$t\t$(sudo -u postgres psql -At benchmark -c "SELECT COUNT(*) FROM $t")"; done | sort > $R/pg-rowcounts.tsv
diff <(sort ~/results/rowcounts.tsv) $R/pg-rowcounts.tsv && log "row counts match MySQL"
sudo -u postgres psql -At benchmark -c "SELECT relname, pg_relation_size(oid), pg_total_relation_size(oid) FROM pg_class WHERE relkind='r' AND relnamespace='public'::regnamespace ORDER BY 1" > $R/tables.tsv
sudo -u postgres psql -At -c "SELECT pg_database_size('benchmark')" > $R/db-bytes.txt
sudo -u postgres psql -At -c "SELECT name, setting, unit, source FROM pg_settings WHERE source NOT IN ('default','override')" > $R/pg-settings.tsv
sudo rm -f $X/*.tsv
nohup pidstat -h -u -r -C postgres 10 > $R/pidstat.log 2>&1 &
date -Is > ~/pgsetup.done; log "pg setup done"
