#!/usr/bin/env bash
# Bootstrap: Blazegraph 2.1.6-RC on DBLP-core.
# DBLP requires blank-node skolemization before loading (default handling silently
# drops ~239M/561M triples). This script skolemizes inline (~30 min) then uses
# the offline DataLoader. Requires ~250 GB disk (73.5 GB nt + 43 GB index).
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/blazegraph}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-180}"

BG_JAR_URL="https://github.com/blazegraph/database/releases/download/BLAZEGRAPH_2_1_6_RC/blazegraph.jar"
TEMURIN_URL="https://api.adoptium.net/v3/binary/latest/11/ga/linux/x64/jdk/hotspot/normal/eclipse"

log() { echo "[blazegraph $(date +%H:%M:%S)] $*"; }

log "=== Blazegraph DBLP-core bootstrap ==="

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq curl pigz unzip python3
# AWS CLI v2 (not in Ubuntu 24.04 apt)
if ! command -v aws &>/dev/null; then
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi
mkdir -p ~/data ~/bench/queries ~/bench/outputs ~/results

# Fetch Java 11 (Ubuntu 24.04 dropped openjdk-11 from apt; use Temurin)
log "Fetching Temurin 11 JDK..."
curl -sSL "$TEMURIN_URL" | tar xz -C ~/
mv ~/jdk-11* ~/jdk11
JAVA=~/jdk11/bin/java

# Fetch everything else in parallel
log "Fetching data, harness, and Blazegraph jar..."
aws s3 cp "$S3_DATA" ~/data/dblp.nt.gz &
DATA_PID=$!

aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh &
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py &
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/ &

curl -sL -o ~/blazegraph.jar "$BG_JAR_URL" &
BG_PID=$!

wait $DATA_PID $BG_PID
wait
chmod +x ~/bench/run_benchmark.sh

# Decompress
log "Decompressing DBLP data (~73.5 GB)..."
pigz -dc ~/data/dblp.nt.gz > ~/data/dblp.nt

# Skolemize blank nodes (required for Blazegraph to load DBLP correctly)
log "Skolemizing blank nodes (~30 min)..."
sed -E 's@_:([A-Za-z0-9_]+)@<https://dblp.org/skbn/\1>@g' \
    ~/data/dblp.nt > ~/data/dblp.skol.nt

# Verify skolemization
REMAINING=$(grep -c '_:' ~/data/dblp.skol.nt || true)
log "Remaining raw blank nodes after skolemization: $REMAINING (expect ~16)"
rm ~/data/dblp.nt  # free disk

# DataLoader properties
cat > ~/fastload.properties <<'EOF'
com.bigdata.journal.AbstractJournal.file=/home/ubuntu/blazegraph.jnl
com.bigdata.journal.AbstractJournal.bufferMode=DiskRW
com.bigdata.rdf.store.AbstractTripleStore.quads=false
com.bigdata.rdf.store.AbstractTripleStore.statementIdentifiers=false
com.bigdata.rdf.store.AbstractTripleStore.textIndex=false
com.bigdata.rdf.store.AbstractTripleStore.axiomsClass=com.bigdata.rdf.axioms.NoAxioms
com.bigdata.rdf.sail.truthMaintenance=false
com.bigdata.namespace.kb.spo.com.bigdata.btree.BTree.branchingFactor=1024
com.bigdata.namespace.kb.lex.com.bigdata.btree.BTree.branchingFactor=400
EOF

log "Running DataLoader (expect ~3 hours)..."
$JAVA -cp ~/blazegraph.jar \
    com.bigdata.rdf.store.DataLoader \
    -defaultGraph https://dblp.org \
    ~/fastload.properties \
    ~/data/dblp.skol.nt 2>&1 | tee ~/dataloader.log

rm ~/data/dblp.skol.nt  # free disk

# Serve
log "Starting Blazegraph server..."
cat > ~/blazegraph-serve.properties <<'EOF'
com.bigdata.journal.AbstractJournal.file=/home/ubuntu/blazegraph.jnl
jetty.port=9999
com.bigdata.rdf.sail.webapp.client.RemoteRepositoryManager.serviceURL=http://localhost:9999/blazegraph
EOF

$JAVA -server -Xmx32g -jar ~/blazegraph.jar &
BG_SERVER_PID=$!
sleep 15

# Verify
COUNT=$(curl -s -X POST "http://localhost:9999/blazegraph/sparql" \
    -H "Accept: text/tab-separated-values" \
    --data-urlencode "query=SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }" | tail -1)
log "COUNT(*) = $COUNT  (expect ~561,477,456)"

# Blazegraph web.xml queryTimeout — set via API if needed
# (the DataLoader properties file doesn't set it; use the JVM arg approach)

# Benchmark
log "Running benchmark..."
cd ~/bench
./run_benchmark.sh \
    --endpoint "http://localhost:9999/blazegraph/sparql" \
    --post-form \
    -r "$BENCH_RUNS" -w "$BENCH_WARMUP" -t "$BENCH_TIMEOUT" \
    --queries ~/bench/queries \
    --save-outputs ~/bench/outputs \
    -o ~/results/blazegraph.tsv

python3 ~/bench/summarize.py ~/results/blazegraph.tsv > ~/results/blazegraph_summary.tsv

# Upload
log "Uploading results..."
aws s3 cp ~/results/blazegraph.tsv         "$S3_RESULTS/blazegraph.tsv"
aws s3 cp ~/results/blazegraph_summary.tsv "$S3_RESULTS/blazegraph_summary.tsv"
aws s3 sync ~/bench/outputs/               "$S3_RESULTS/query-outputs/"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
kill $BG_SERVER_PID 2>/dev/null || true
log "=== Blazegraph bootstrap complete ==="
