#!/usr/bin/env bash
# Reproduce the published v4.2.0 DBLP run on a fresh Ubuntu 24.04 x86_64 host.
set -euo pipefail
if [[ $# != 1 ]]; then
    echo "Usage: $0 /path/to/new-run" >&2
    exit 2
fi
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for cmd in curl pigz python3 sha256sum tar xz; do command -v "$cmd" >/dev/null; done
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
    echo 'This run pins the Linux x86_64 release binary.' >&2; exit 1;
}
# Require a new directory to avoid overwriting an existing ledger or results.
mkdir -- "$1"
RUN_DIR="$(cd "$1" && pwd)"
mkdir -p "$RUN_DIR"/{bin,data,ledger,results}
exec > >(tee "$RUN_DIR/results/run.log") 2>&1
server_pid=''
cleanup() {
    rc=$?
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    echo "$rc" > "$RUN_DIR/results/exit-code.txt"
}
trap cleanup EXIT
ulimit -n 1048576
python3 - "$REPO_ROOT" <<'PY'
import hashlib,json,sys
from pathlib import Path
r=Path(sys.argv[1]);manifest=r/'benchmarks/sparqloscope/reports/dblp-core/v420-release/harness-sha256.json'
for name,expected in json.loads(manifest.read_text()).items():
    assert hashlib.sha256((r/name).read_bytes()).hexdigest()==expected, f'Harness differs: {name}'
print('Harness hashes verified')
PY
curl --proto '=https' --tlsv1.2 -fLsS --retry 3 \
    https://github.com/fluree/db/releases/download/v4.2.0/fluree-db-cli-installer.sh \
    -o "$RUN_DIR/installer.sh"
printf '%s  %s\n' e03c4fae87ab8581fb61eef77f6762ecf1dc6d593df26a690b805a4eb33aa674 "$RUN_DIR/installer.sh" | sha256sum -c -
FLUREE_DB_CLI_INSTALL_DIR="$RUN_DIR/bin" FLUREE_DB_CLI_NO_MODIFY_PATH=1 sh "$RUN_DIR/installer.sh"
printf '%s  %s\n' 03314b1de786268d07b96bca2c45e87c97f966a74780b1ae4700fba55f9c9fc4 "$RUN_DIR/bin/fluree" | sha256sum -c -
"$RUN_DIR/bin/fluree" --version
curl --proto '=https' --tlsv1.2 -fLsS --retry 3 \
    https://drops.dagstuhl.de/storage/artifacts/dblp/rdf/2026/dblp-2026-06-01.nt.gz \
    -o "$RUN_DIR/data/dblp.nt.gz"
printf '%s  %s\n' 6a1edc1b7aebcd7a581bc4313243029952af4af0fbf900e4126a72d6deb92309 "$RUN_DIR/data/dblp.nt.gz" | sha256sum -c -
pigz -dc "$RUN_DIR/data/dblp.nt.gz" > "$RUN_DIR/data/dblp.nt"
cd "$RUN_DIR/ledger"
"$RUN_DIR/bin/fluree" init
start=$SECONDS
"$RUN_DIR/bin/fluree" create dblp --from "$RUN_DIR/data/dblp.nt" > "$RUN_DIR/results/import.log" 2>&1
echo "$((SECONDS-start))" > "$RUN_DIR/results/import-seconds.txt"
# Refuse an occupied port so the queries cannot accidentally hit another server.
python3 - <<'PY'
import socket
with socket.socket() as s:
    s.bind(('127.0.0.1',8090))
PY
"$RUN_DIR/bin/fluree" server run --listen-addr 127.0.0.1:8090 > "$RUN_DIR/results/server.log" 2>&1 &
server_pid=$!
ready=0
for ((i=0; i<120; i++)); do
    kill -0 "$server_pid" 2>/dev/null || { echo 'Server exited; see server.log' >&2; exit 1; }
    if curl -fsS http://127.0.0.1:8090/health >/dev/null 2>&1; then ready=1; break; fi
    sleep 1
done
[[ "$ready" == 1 ]] || { echo 'Server readiness timed out' >&2; exit 1; }
curl -fsS http://127.0.0.1:8090/v1/fluree/query/dblp:main \
    -H 'Content-Type: application/sparql-query' -H 'Accept: text/tab-separated-values' \
    --data 'SELECT (COUNT(*) AS ?c) WHERE {?s ?p ?o}' > "$RUN_DIR/results/count.tsv"
grep -q 561477456 "$RUN_DIR/results/count.tsv"
bash "$REPO_ROOT/common/run_benchmark.sh" \
    --endpoint http://127.0.0.1:8090/v1/fluree/query/dblp:main \
    --queries "$REPO_ROOT/benchmarks/sparqloscope/queries" -w 1 -r 3 -t 180 \
    --save-outputs "$RUN_DIR/results/outputs" -o "$RUN_DIR/results/fluree.tsv"
python3 - "$RUN_DIR/results/fluree.tsv" <<'PY'
import csv,sys
from collections import Counter
rows=list(csv.DictReader(open(sys.argv[1]),delimiter='\t'))
counts=Counter(r['query_id'] for r in rows)
assert len(counts)==105 and all(n==3 for n in counts.values()), 'Incomplete measured samples'
assert all(r['status']=='200' for r in rows), 'Query errors; inspect fluree.tsv'
print('105/105 queries passed; all 315 measured requests succeeded')
PY
