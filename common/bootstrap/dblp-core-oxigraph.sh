#!/usr/bin/env bash
# Bootstrap: Oxigraph 0.5.8 on DBLP-core.
# Uses the documented per-query restart methodology (no server-side timeout,
# no COUNT fastpath): 1 run per query, 180s curl timeout, memory-capped under
# systemd, restart-on-failure. Results are NOT directly comparable to
# warmup+median-of-3 engines; read as "completed vs timed out".
set -euo pipefail

# If AWS creds are absent (e.g. a manual rerun session), recover the full
# launch env (S3 paths, creds) from ~/bench.env persisted by the launch script.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -f ~/bench.env ]]; then
    source ~/bench.env
fi

S3_DATA="${S3_DATA:-s3://fluree-benchmark-data/dblp-core/dblp-2026-06-01.nt.gz}"
S3_RESULTS="${S3_RESULTS:-s3://fluree-benchmark-data/runs/unset/oxigraph}"
BENCH_TIMEOUT="${BENCH_TIMEOUT:-180}"

OXIGRAPH_VERSION="0.5.8"
OXIGRAPH_URL="https://github.com/oxigraph/oxigraph/releases/download/v${OXIGRAPH_VERSION}/oxigraph_v${OXIGRAPH_VERSION}_x86_64_linux_gnu"
MEMORY_CAP="52G"

log() { echo "[oxigraph $(date +%H:%M:%S)] $*"; }

log "=== Oxigraph DBLP-core bootstrap ==="

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
mkdir -p ~/data ~/oxigraph ~/bench/queries ~/bench/outputs ~/results

# Fetch in parallel
log "Fetching data, harness, and Oxigraph binary..."
aws s3 cp "$S3_DATA" ~/data/dblp.nt.gz &
DATA_PID=$!

aws s3 cp "${S3_RESULTS%/*}/harness/run_benchmark.sh" ~/bench/run_benchmark.sh &
aws s3 cp "${S3_RESULTS%/*}/harness/summarize.py" ~/bench/summarize.py &
aws s3 sync "${S3_RESULTS%/*}/harness/queries/" ~/bench/queries/ &

curl -sL -o ~/oxigraph/oxigraph "$OXIGRAPH_URL" &
OX_PID=$!

wait $DATA_PID $OX_PID
wait
chmod +x ~/bench/run_benchmark.sh ~/oxigraph/oxigraph

# Load
log "Decompressing data and loading into Oxigraph..."
pigz -dc ~/data/dblp.nt.gz > ~/data/dblp.nt
~/oxigraph/oxigraph load --location ~/oxigraph/data --file ~/data/dblp.nt --format nt --lenient
log "Load + RocksDB compaction complete. Index size: $(du -sh ~/oxigraph/data | cut -f1)"
rm ~/data/dblp.nt

# Per-query restart wrapper — mirrors ad-freiburg/sparqloscope util/oxigraph-helper.sh
# Oxigraph: no server-side timeout, no COUNT fastpath → most queries time out.
# Write directly in the run_benchmark.sh TSV format.
log "Starting memory-capped Oxigraph and running benchmark..."

start_oxigraph() {
    sudo systemd-run -p "MemoryMax=$MEMORY_CAP" -p MemorySwapMax=0 \
        --unit=oxbench --collect \
        ~/oxigraph/oxigraph serve-read-only \
            --location ~/oxigraph/data \
            --bind localhost:7878 \
        >> ~/oxigraph-server.log 2>&1 &
    sleep 5
}

stop_oxigraph() {
    sudo systemctl stop oxbench 2>/dev/null || true
    sleep 2
}

printf "query_id\tdescription\trun\tstatus\ttime_ms\tresult_size\terror\n" > ~/results/oxigraph.tsv

start_oxigraph

QUERIES_DIR=~/bench/queries
for qf in "$QUERIES_DIR"/*.sparql; do
    query_id=$(basename "$qf" .sparql)
    description=""
    first_line=$(head -1 "$qf")
    [[ "$first_line" == "# "* ]] && description="${first_line:2}"
    sparql=$(grep -v '^#' "$qf" | tr '\n' ' ')

    tmpfile=$(mktemp)
    read -r http_code time_total < <(curl -s -o "$tmpfile" \
        -w "%{http_code} %{time_total}\n" \
        --max-time "$BENCH_TIMEOUT" \
        -X POST "http://localhost:7878/query" \
        -H "Accept: text/tab-separated-values" \
        -H "Content-Type: application/sparql-query" \
        --data "$sparql" 2>/dev/null) || { http_code="000"; time_total="0"; }

    elapsed_ms=$(awk -v t="$time_total" 'BEGIN { printf "%.3f", t * 1000 }')
    result_size=$(wc -c < "$tmpfile" | tr -d ' ')
    error=""
    [[ "$http_code" != "200" ]] && error=$(head -c 200 "$tmpfile" | tr '\t\n' '  ')

    printf "%s\t%s\t%d\t%s\t%s\t%s\t%s\n" \
        "$query_id" "$description" "1" "$http_code" "$elapsed_ms" "$result_size" "$error" \
        >> ~/results/oxigraph.tsv

    if [[ "$http_code" == "200" ]]; then
        mkdir -p ~/bench/outputs
        cp "$tmpfile" ~/bench/outputs/"${query_id}-run1.tsv"
        printf "OK  %9s ms  %s bytes\n" "$elapsed_ms" "$result_size"
    elif [[ "$http_code" == "000" ]]; then
        printf "TIMEOUT after %ds — restarting server\n" "$BENCH_TIMEOUT"
        stop_oxigraph
        start_oxigraph
    else
        printf "FAIL HTTP %s — restarting server\n" "$http_code"
        stop_oxigraph
        start_oxigraph
    fi
    rm -f "$tmpfile"
done

stop_oxigraph

python3 ~/bench/summarize.py ~/results/oxigraph.tsv > ~/results/oxigraph_summary.tsv

# Upload
log "Uploading results..."
aws s3 cp ~/results/oxigraph.tsv         "$S3_RESULTS/oxigraph.tsv"
aws s3 cp ~/results/oxigraph_summary.tsv "$S3_RESULTS/oxigraph_summary.tsv"
aws s3 sync ~/bench/outputs/             "$S3_RESULTS/query-outputs/"
echo "done" | aws s3 cp - "$S3_RESULTS/done.flag"
log "=== Oxigraph bootstrap complete ==="
