#!/usr/bin/env bash
#
# Run the Memgraph benchgraph Pokec query set against a running Fluree server
# over the Cypher HTTP surface. Query texts are the verbatim Neo4j-portable
# branch from memgraph/tests/mgbench/workloads/pokec.py (see upstream/).
#
# Usage:
#   ./run_benchmark.sh [options]
#
# Options:
#   -h, --host HOST      Server host (default: localhost)
#   -p, --port PORT      Server port (default: 8090)
#   -l, --ledger LEDGER  Ledger name (default: pokec)
#   -r, --runs N         Timed runs per query (default: 3)
#   -w, --warmup N       Warmup runs before timing (default: 1)
#   -o, --output FILE    Output results file (default: results/<timestamp>.tsv)
#   -q, --query PATTERN  Only run queries matching glob pattern (default: *)
#   -t, --timeout SECS   Query timeout in seconds (default: 120)
#   --seed N             RNG seed for parameter sampling (default: 42)
#   --num-vertices N     Vertex-id upper bound for $id/$from/$to sampling
#                        (default: 10000 = pokec small; medium 100000,
#                        large 1632803)
#   --skip-writes        Skip kind=write queries (leave the ledger unmutated)
#   --dry-run            Print the request envelopes without executing
#
# Parameterization follows pokec.py: $id / $from / $to are sampled uniformly
# from [1, num-vertices] ($from != $to), single_vertex_write samples from
# [1, 10*num-vertices]. Sampling is seeded, so a given (seed, query set, runs)
# is reproducible.
#
# Timing: elapsed time is curl's own %{time_total} — full client-observed
# round trip, no per-run subprocess in the timed path. Envelope construction
# (jq) happens before the request and is not counted.
#
# NOTE: write queries mutate the ledger. For a clean re-run, re-create the
# ledger from the .ttl import (or use --skip-writes).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUERIES_DIR="$SCRIPT_DIR/queries"
RESULTS_DIR="$SCRIPT_DIR/results"
QUERY_SET="$SCRIPT_DIR/query-set.tsv"

HOST="localhost"
PORT="8090"
LEDGER="pokec"
RUNS=3
WARMUP=1
OUTPUT=""
QUERY_PATTERN="*"
TIMEOUT=120
SEED=42
NUM_VERTICES=10000
SKIP_WRITES=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)       HOST="$2"; shift 2 ;;
        -p|--port)       PORT="$2"; shift 2 ;;
        -l|--ledger)     LEDGER="$2"; shift 2 ;;
        -r|--runs)       RUNS="$2"; shift 2 ;;
        -w|--warmup)     WARMUP="$2"; shift 2 ;;
        -o|--output)     OUTPUT="$2"; shift 2 ;;
        -q|--query)      QUERY_PATTERN="$2"; shift 2 ;;
        -t|--timeout)    TIMEOUT="$2"; shift 2 ;;
        --seed)          SEED="$2"; shift 2 ;;
        --num-vertices)  NUM_VERTICES="$2"; shift 2 ;;
        --skip-writes)   SKIP_WRITES=true; shift ;;
        --dry-run)       DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

BASE_URL="http://${HOST}:${PORT}"
QUERY_URL="${BASE_URL}/v1/fluree/query/${LEDGER}:main"
UPDATE_URL="${BASE_URL}/v1/fluree/update/${LEDGER}:main"

if ! $DRY_RUN && ! curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health" | grep -q "200"; then
    echo "ERROR: Fluree server not reachable at ${BASE_URL}"
    exit 1
fi

command -v jq >/dev/null || { echo "ERROR: jq is required"; exit 1; }

mkdir -p "$RESULTS_DIR"
if [[ -z "$OUTPUT" ]]; then
    OUTPUT="$RESULTS_DIR/benchmark_$(date +%Y%m%d_%H%M%S).tsv"
fi

# Seeded RNG. bash's RANDOM is 15-bit, so compose two draws for ids > 32767.
RANDOM=$SEED
rand_range() { # rand_range MAX -> uniform int in [1, MAX]
    local max=$1
    echo $(( ( (RANDOM << 15 | RANDOM) % max ) + 1 ))
}

# Emit the params JSON object for a query's param spec.
gen_params() {
    case "$1" in
        none)  echo '{}' ;;
        id)    echo "{\"id\": $(rand_range "$NUM_VERTICES")}" ;;
        id10x) echo "{\"id\": $(rand_range $((NUM_VERTICES * 10)))}" ;;
        from_to)
            local from to
            from=$(rand_range "$NUM_VERTICES")
            to=$from
            while [[ "$to" == "$from" ]]; do to=$(rand_range "$NUM_VERTICES"); done
            echo "{\"from\": $from, \"to\": $to}"
            ;;
        *) echo "ERROR: unknown param spec '$1'" >&2; return 1 ;;
    esac
}

echo "=== benchgraph Pokec (Fluree Cypher runner) ==="
echo "  Query URL:  $QUERY_URL"
echo "  Update URL: $UPDATE_URL"
echo "  Runs:       $RUNS (+ $WARMUP warmup)   Timeout: ${TIMEOUT}s"
echo "  Vertices:   $NUM_VERTICES   Seed: $SEED"
echo "  Output:     $OUTPUT"
echo ""

printf "query_id\tdescription\trun\tstatus\ttime_ms\tresult_size\terror\n" > "$OUTPUT"

PASS=0; FAIL=0; SKIP=0
while IFS=$'\t' read -r qid kind params desc; do
    [[ "$qid" == "query_id" ]] && continue
    # shellcheck disable=SC2053
    [[ "$qid" == $QUERY_PATTERN ]] || continue
    if $SKIP_WRITES && [[ "$kind" == "write" ]]; then
        echo "SKIP  $qid (write)"; SKIP=$((SKIP+1)); continue
    fi

    qfile="$QUERIES_DIR/$qid.cypher"
    if [[ ! -f "$qfile" ]]; then
        echo "MISS  $qid (no query file)"; continue
    fi
    url="$QUERY_URL"
    [[ "$kind" == "write" ]] && url="$UPDATE_URL"

    query_failed=false
    for run in $(seq 1 $((WARMUP + RUNS))); do
        envelope=$(jq -n --rawfile q "$qfile" --argjson p "$(gen_params "$params")" \
            '{cypher: $q, params: $p}')
        if $DRY_RUN; then
            [[ $run -eq 1 ]] && { echo "--- $qid ($kind)"; echo "$envelope"; }
            continue
        fi

        body_file=$(mktemp)
        read -r http_code time_total < <(curl -s -o "$body_file" \
            -w "%{http_code} %{time_total}" \
            --max-time "$TIMEOUT" \
            -X POST "$url" \
            -H 'Content-Type: application/cypher' \
            --data "$envelope" 2>/dev/null || echo "000 $TIMEOUT")
        time_ms=$(awk -v t="$time_total" 'BEGIN{printf "%.3f", t*1000}')

        label="run$((run - WARMUP))"
        [[ $run -le $WARMUP ]] && label="warmup$run"

        if [[ "$http_code" == "200" ]]; then
            if [[ "$kind" == "write" ]]; then
                # a write with RETURN answers a rowset; without one, a commit receipt
                size=$(jq -r 'if .results then (.results[0].data | length) elif .["tx-id"] then 1 else 0 end' "$body_file" 2>/dev/null || echo 0)
                err=""
            else
                size=$(jq -r '.results[0].data | length' "$body_file" 2>/dev/null || echo "")
                err=""
                [[ -z "$size" ]] && { err="unparseable response"; }
            fi
        else
            size=""
            err=$(head -c 300 "$body_file" | tr '\t\n' '  ')
            [[ "$http_code" == "000" ]] && err="timeout/connection error"
            query_failed=true
        fi
        rm -f "$body_file"

        if [[ $run -gt $WARMUP ]]; then
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
                "$qid" "$desc" "$label" "$http_code" "$time_ms" "$size" "$err" >> "$OUTPUT"
        fi
    done

    $DRY_RUN && continue
    if $query_failed; then
        echo "FAIL  $qid — $err"
        FAIL=$((FAIL+1))
    else
        echo "OK    $qid  (${time_ms}ms, rows=${size})"
        PASS=$((PASS+1))
    fi
done < "$QUERY_SET"

echo ""
echo "=== done: $PASS ok, $FAIL failed, $SKIP skipped -> $OUTPUT ==="
