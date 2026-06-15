#!/usr/bin/env bash
# Bootstrap: Virtuoso 7.2.5.1 on DBLP-core.
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/virtuoso}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-180}"

log() { echo "[virtuoso $(date +%H:%M:%S)] $*"; }

log "=== Virtuoso DBLP-core bootstrap ==="

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq pigz unzip virtuoso-opensource curl python3
# AWS CLI v2 (not in Ubuntu 24.04 apt)
if ! command -v aws &>/dev/null; then
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi

mkdir -p ~/bench/queries ~/bench/outputs ~/results
# Data goes under /tmp/virt-data so the virtuoso service user can read it
sudo mkdir -p /tmp/virt-data
sudo chmod 1777 /tmp/virt-data

# Stop Virtuoso so we can reconfigure
sudo systemctl stop virtuoso-opensource-7

# Configure Virtuoso (32 GB profile for 64 GB box)
sudo tee /etc/virtuoso-opensource-7/virtuoso.ini > /dev/null <<'EOF'
[Database]
DatabaseFile    = /var/lib/virtuoso-opensource-7/db/virtuoso.db
TransactionFile = /var/lib/virtuoso-opensource-7/db/virtuoso.trx
ErrorLogFile    = /var/lib/virtuoso-opensource-7/db/virtuoso.log

[Parameters]
NumberOfBuffers  = 2720000
MaxDirtyBuffers  = 2000000
ServerThreads    = 100
DirsAllowed      = ., /usr/share/virtuoso-opensource-7/vad, /tmp/virt-data

[SPARQL]
DefaultGraph          = https://dblp.org
ResultSetMaxRows      = 10000000
MaxQueryExecutionTime = 300

[HTTPServer]
ServerPort = 8890
ServerRoot = /usr/share/virtuoso-opensource-7/vsp
EOF

sudo systemctl start virtuoso-opensource-7
sleep 10

# Data
log "Fetching and decompressing data..."
aws s3 cp "$S3_DATA" /tmp/virt-data/dblp.nt.gz
pigz -dc /tmp/virt-data/dblp.nt.gz > /tmp/virt-data/dblp.nt
rm /tmp/virt-data/dblp.nt.gz
log "Splitting into 16 chunks for parallel load..."
cd /tmp/virt-data
split -n l/16 -d -a 2 --additional-suffix=.nt dblp.nt part_
rm dblp.nt  # free disk

# Harness
log "Fetching harness..."
aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/
chmod +x ~/bench/run_benchmark.sh

# Queue files and spawn 8 loader threads
log "Queueing data for load..."
isql-vt 1111 dba dba exec="ld_dir('/tmp/virt-data', '*.nt', 'https://dblp.org');"
QUEUED=$(isql-vt 1111 dba dba exec="SELECT COUNT(*) FROM DB.DBA.LOAD_LIST WHERE ll_state=0;" \
    | grep -oE '[0-9]+' | tail -1)
log "Queued $QUEUED files for loading."
log "Loading data (8 parallel rdf_loader_run)..."
for i in $(seq 1 8); do
    isql-vt 1111 dba dba exec="rdf_loader_run();" &
done

# Poll until all items reach state=2 (done)
log "Waiting for loaders to finish..."
while true; do
    PENDING=$(isql-vt 1111 dba dba exec="SELECT COUNT(*) FROM DB.DBA.LOAD_LIST WHERE ll_state <> 2;" \
        2>/dev/null | grep -oE '[0-9]+' | tail -1)
    [ "${PENDING:-1}" = "0" ] && break
    log "Still loading: ${PENDING} items pending..."
    sleep 30
done
wait
isql-vt 1111 dba dba exec="checkpoint;"
log "Load complete."

# Verify
COUNT=$(isql-vt 1111 dba dba exec="SPARQL SELECT (COUNT(*) AS ?c) WHERE { GRAPH <https://dblp.org> { ?s ?p ?o } };" \
    | grep -oE '[0-9]+' | tail -1)
log "COUNT(*) = $COUNT"

# Benchmark
log "Running benchmark..."
cd ~/bench
./run_benchmark.sh \
    --endpoint "http://localhost:8890/sparql" \
    --post-form \
    --default-graph "https://dblp.org" \
    -r "$BENCH_RUNS" -w "$BENCH_WARMUP" -t "$BENCH_TIMEOUT" \
    --queries ~/bench/queries \
    --save-outputs ~/bench/outputs \
    -o ~/results/virtuoso.tsv

python3 ~/bench/summarize.py ~/results/virtuoso.tsv > ~/results/virtuoso_summary.tsv

# Upload
log "Uploading results..."
aws s3 cp ~/results/virtuoso.tsv         "$S3_RESULTS/virtuoso.tsv"
aws s3 cp ~/results/virtuoso_summary.tsv "$S3_RESULTS/virtuoso_summary.tsv"
aws s3 sync ~/bench/outputs/             "$S3_RESULTS/query-outputs/"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
log "=== Virtuoso bootstrap complete ==="
