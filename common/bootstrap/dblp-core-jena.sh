#!/usr/bin/env bash
# Bootstrap: Apache Jena 6.1.0 / Fuseki on DBLP-core.
# NOTE: xloader import takes ~2 hours. This box needs a 400 GB disk.
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/jena}"
BENCH_RUNS="${BENCH_RUNS:-3}"
BENCH_WARMUP="${BENCH_WARMUP:-1}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-180}"

JENA_VERSION="6.1.0"

log() { echo "[jena $(date +%H:%M:%S)] $*"; }

log "=== Jena DBLP-core bootstrap ==="

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq openjdk-21-jdk-headless curl pigz unzip python3
# AWS CLI v2 (not in Ubuntu 24.04 apt)
if ! command -v aws &>/dev/null; then
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi

mkdir -p ~/data ~/jena ~/bench/queries ~/bench/outputs ~/results ~/jena/tmp

# Fetch data + harness + Jena in parallel
log "Fetching data, harness, and Jena binaries..."
aws s3 cp "$S3_DATA" ~/data/dblp.nt.gz &
DATA_PID=$!

aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh &
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py &
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/ &

cd ~/jena
for f in "apache-jena-${JENA_VERSION}" "apache-jena-fuseki-${JENA_VERSION}"; do
    curl -sL -O "https://dlcdn.apache.org/jena/binaries/${f}.tar.gz" &
done

wait
chmod +x ~/bench/run_benchmark.sh
for f in "apache-jena-${JENA_VERSION}" "apache-jena-fuseki-${JENA_VERSION}"; do
    tar -xzf "${f}.tar.gz"
done

XLOADER="$HOME/jena/apache-jena-${JENA_VERSION}/bin/tdb2.xloader"
FUSEKI="$HOME/jena/apache-jena-fuseki-${JENA_VERSION}/fuseki-server"

log "Decompressing data..."
pigz -dc ~/data/dblp.nt.gz > ~/data/dblp.nt

# xloader — external-sort bulk loader; --loc dir must NOT pre-exist
log "Running tdb2.xloader (expect ~2 hours)..."
$XLOADER --loc ~/jena/tdb --tmpdir ~/jena/tmp ~/data/dblp.nt
log "xloader complete. Index size: $(du -sh ~/jena/tdb | cut -f1)"

# Free temp + uncompressed data
rm -rf ~/jena/tmp ~/data/dblp.nt

# Serve
log "Starting Fuseki..."
JVM_ARGS='-Xmx32g' $FUSEKI \
    --loc ~/jena/tdb --timeout=300000 /dblp \
    --port 3030 &
FUSEKI_PID=$!
sleep 15

# Verify
COUNT=$(curl -s -X POST "http://localhost:3030/dblp/sparql" \
    -H "Accept: text/tab-separated-values" \
    --data 'SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' | tail -1)
log "COUNT(*) = $COUNT"

# Benchmark
log "Running benchmark..."
cd ~/bench
./run_benchmark.sh \
    --endpoint "http://localhost:3030/dblp/sparql" \
    -r "$BENCH_RUNS" -w "$BENCH_WARMUP" -t "$BENCH_TIMEOUT" \
    --queries ~/bench/queries \
    --save-outputs ~/bench/outputs \
    -o ~/results/jena.tsv

python3 ~/bench/summarize.py ~/results/jena.tsv > ~/results/jena_summary.tsv

# Upload
log "Uploading results..."
aws s3 cp ~/results/jena.tsv         "$S3_RESULTS/jena.tsv"
aws s3 cp ~/results/jena_summary.tsv "$S3_RESULTS/jena_summary.tsv"
aws s3 sync ~/bench/outputs/         "$S3_RESULTS/query-outputs/"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
kill $FUSEKI_PID 2>/dev/null || true
log "=== Jena bootstrap complete ==="
