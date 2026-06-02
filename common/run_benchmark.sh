#!/usr/bin/env bash
#
# Run the SPARQLoscope DBLP benchmark queries against a running Fluree server.
#
# Usage:
#   ./run_benchmark.sh [options]
#
# Options:
#   -h, --host HOST      Server host (default: localhost)
#   -p, --port PORT      Server port (default: 8090)
#   -l, --ledger LEDGER  Ledger name (default: dblp)
#   -r, --runs N         Number of timed runs per query (default: 3)
#   -w, --warmup N       Warmup runs before timing (default: 1)
#   -o, --output FILE    Output results file (default: results/<timestamp>.tsv)
#   -q, --query PATTERN  Only run queries matching glob pattern
#   -s, --start N        Start at query number N (1-based, default: 1)
#   -t, --timeout SECS   Query timeout in seconds (default: 300)
#   --accept TYPE        Accept header (default: text/tab-separated-values)
#   --dry-run            Print queries without executing
#
# Timing note: elapsed time is measured by curl itself (`-w %{time_total}`),
# the full client-observed round trip for the POST. No per-run subprocess
# spawns, so sub-millisecond queries are not inflated by harness overhead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Generic runner (lives in common/): query/results dirs are relative to the
# directory you invoke it from (a benchmark dir), or set with --queries.
QUERIES_DIR="queries"
RESULTS_DIR="results"

# Defaults
HOST="localhost"
PORT="8090"
LEDGER="dblp"
RUNS=3
WARMUP=1
OUTPUT=""
QUERY_PATTERN="*.sparql"
TIMEOUT=300
START=1
# SPARQLoscope measures result serialization in TSV (text/tab-separated-values),
# the compact row format the upstream harness uses. Requesting JSON instead
# inflates large-result queries (result-size-*) several-fold and is not
# comparable to the published numbers.
ACCEPT="text/tab-separated-values"
ENDPOINT=""
CLEAR_URL=""
DRY_RUN=false
# POST mode: "body" sends the query as an application/sparql-query body (Fluree,
# QLever, Fuseki, Blazegraph, Oxigraph). "form" url-encodes it as query=... which
# some engines require (Virtuoso). --default-graph adds default-graph-uri (form).
POST_MODE="body"
DEFAULT_GRAPH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)    HOST="$2"; shift 2 ;;
        -p|--port)    PORT="$2"; shift 2 ;;
        -l|--ledger)  LEDGER="$2"; shift 2 ;;
        -r|--runs)    RUNS="$2"; shift 2 ;;
        -w|--warmup)  WARMUP="$2"; shift 2 ;;
        -o|--output)  OUTPUT="$2"; shift 2 ;;
        -q|--query)   QUERY_PATTERN="$2"; shift 2 ;;
        --queries)    QUERIES_DIR="$2"; shift 2 ;;
        -s|--start)   START="$2"; shift 2 ;;
        -t|--timeout) TIMEOUT="$2"; shift 2 ;;
        --accept)     ACCEPT="$2"; shift 2 ;;
        --endpoint)   ENDPOINT="$2"; shift 2 ;;
        --clear-url)  CLEAR_URL="$2"; shift 2 ;;
        --post-form)  POST_MODE="form"; shift ;;
        --default-graph) DEFAULT_GRAPH="$2"; shift 2 ;;
        --dry-run)    DRY_RUN=true; shift ;;
        *)            echo "Unknown option: $1"; exit 1 ;;
    esac
done

BASE_URL="http://${HOST}:${PORT}"
# --endpoint overrides the URL entirely (e.g. for QLever or any SPARQL endpoint);
# otherwise default to Fluree's ledger query path.
if [[ -n "$ENDPOINT" ]]; then
    QUERY_URL="$ENDPOINT"
else
    QUERY_URL="${BASE_URL}/v1/fluree/query/${LEDGER}:main"
    # Fluree health check (skipped for custom endpoints)
    if ! curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health" | grep -q "200"; then
        echo "ERROR: Fluree server not reachable at ${BASE_URL}"
        echo "Start it first (in another terminal):  fluree server run"
        exit 1
    fi
fi

# Set up output file
mkdir -p "$RESULTS_DIR"
if [[ -z "$OUTPUT" ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUTPUT="$RESULTS_DIR/benchmark_${TIMESTAMP}.tsv"
fi

echo "=== SPARQLoscope DBLP Benchmark ==="
echo "  Server:      $QUERY_URL"
echo "  Runs:        $RUNS (+ $WARMUP warmup)"
echo "  Timeout:     ${TIMEOUT}s"
echo "  Accept:      $ACCEPT"
echo "  Output:      $OUTPUT"
echo "  Start at:    $START"
echo "  Pattern:     $QUERY_PATTERN"
echo ""

# Build the curl POST data args for one query (raw body vs url-encoded form).
post_args() {
    if [[ "$POST_MODE" == "form" ]]; then
        POST_ARGS=(--data-urlencode "query=$1")
        [[ -n "$DEFAULT_GRAPH" ]] && POST_ARGS+=(--data-urlencode "default-graph-uri=$DEFAULT_GRAPH")
    else
        POST_ARGS=(-H "Content-Type: application/sparql-query" --data "$1")
    fi
    # NB: must return 0 — the `[[ -n ... ]] &&` above is false when --default-graph
    # is unset (e.g. Blazegraph --post-form), and under `set -e` a non-zero return
    # here would abort the whole run at the first query.
    return 0
}

# Write TSV header
printf "query_id\tdescription\trun\tstatus\ttime_ms\tresult_size\terror\n" > "$OUTPUT"

# Collect query files
QUERY_FILES=()
for f in "$QUERIES_DIR"/$QUERY_PATTERN; do
    [[ -f "$f" ]] && QUERY_FILES+=("$f")
done

TOTAL=${#QUERY_FILES[@]}
echo "Found $TOTAL queries matching '$QUERY_PATTERN'"
echo ""

if $DRY_RUN; then
    for qf in "${QUERY_FILES[@]}"; do
        query_id=$(basename "$qf" .sparql)
        echo "  $query_id"
    done
    echo ""
    echo "(dry run — no queries executed)"
    exit 0
fi

# Run benchmark
PASSED=0
FAILED=0
ERRORS=0

for idx in "${!QUERY_FILES[@]}"; do
    qf="${QUERY_FILES[$idx]}"
    query_id=$(basename "$qf" .sparql)
    n=$((idx + 1))

    # Skip queries before start
    if [[ $n -lt $START ]]; then
        continue
    fi

    # Extract description from first line comment
    description=""
    first_line=$(head -1 "$qf")
    if [[ "$first_line" == "# "* ]]; then
        description="${first_line:2}"
    fi

    # Read the SPARQL query (skip comment lines)
    sparql=$(grep -v '^#' "$qf" | tr '\n' ' ')

    printf "[%3d/%d] %-55s " "$n" "$TOTAL" "$query_id"

    # Warmup runs (silent), capturing the last warmup's status for early-abort.
    warmup_code="200"
    for ((w = 1; w <= WARMUP; w++)); do
        # Optional pre-query cache clear (e.g. QLever) so each run re-executes
        # rather than serving a cached result — keeps engines comparable.
        [[ -n "$CLEAR_URL" ]] && curl -s -o /dev/null --max-time 30 "$CLEAR_URL" 2>/dev/null || true
        post_args "$sparql"
        warmup_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time "$TIMEOUT" \
            -X POST "$QUERY_URL" \
            -H "Accept: $ACCEPT" \
            "${POST_ARGS[@]}" 2>/dev/null) || warmup_code="000"
    done

    # Early-abort: a query that times out on warmup will time out on every timed
    # run too. Record it as a timeout (one row per run, for output consistency)
    # and skip the timed runs — saves (RUNS x TIMEOUT) of re-timing-out the same
    # query. Only triggers with a warmup (WARMUP>=1); the timeout threshold is
    # unchanged, so results stay comparable.
    if [[ "$warmup_code" == "000" ]]; then
        to_ms=$(( TIMEOUT * 1000 ))
        for ((r = 1; r <= RUNS; r++)); do
            printf "%s\t%s\t%d\t%s\t%d\t%s\t%s\n" \
                "$query_id" "$description" "$r" "000" "$to_ms" "0" "early-abort: warmup timed out" \
                >> "$OUTPUT"
        done
        printf "TIMEOUT after %ds (early-abort)\n" "$TIMEOUT"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Timed runs, capped at a ~TIMEOUT total budget per query: once a query's
    # cumulative timed wall would exceed the timeout, skip the remaining runs
    # (and stop immediately on a timeout/error). Matches SPARQLoscope's "max
    # <timeout> per query" — fast queries still get the full median-of-RUNS,
    # but a query that takes ~TIMEOUT for one run is measured once, not RUNS×.
    times=()
    last_status=""
    last_size=""
    last_error=""
    budget_ms=$(( TIMEOUT * 1000 ))
    cumulative_ms=0
    elapsed_ms=0

    for ((r = 1; r <= RUNS; r++)); do
        # Before a follow-up run, stop if another run (~the last one's time)
        # would push this query past its time budget.
        if (( r > 1 )) && (( cumulative_ms + elapsed_ms > budget_ms )); then
            break
        fi
        tmpfile=$(mktemp)

        # Optional pre-query cache clear (not part of the timed measurement).
        [[ -n "$CLEAR_URL" ]] && curl -s -o /dev/null --max-time 30 "$CLEAR_URL" 2>/dev/null || true

        # curl reports both the HTTP status and its own measured total time.
        # %{time_total} is fractional seconds; convert to integer ms.
        # NB: -w must end in \n so `read` sees a complete line and returns 0;
        # without it read hits EOF, returns non-zero, and the `||` fallback below
        # clobbers the real values with 000 (which then looks like a timeout).
        post_args "$sparql"
        read -r http_code time_total < <(curl -s -o "$tmpfile" \
            -w "%{http_code} %{time_total}\n" \
            --max-time "$TIMEOUT" \
            -X POST "$QUERY_URL" \
            -H "Accept: $ACCEPT" \
            "${POST_ARGS[@]}" 2>/dev/null) || { http_code="000"; time_total="0"; }

        elapsed_ms=$(awk -v t="$time_total" 'BEGIN { printf "%d", t * 1000 }')
        result_size=$(wc -c < "$tmpfile" | tr -d ' ')

        error=""
        if [[ "$http_code" != "200" ]]; then
            error=$(head -c 200 "$tmpfile" | tr '\t\n' '  ')
        fi

        printf "%s\t%s\t%d\t%s\t%d\t%s\t%s\n" \
            "$query_id" "$description" "$r" "$http_code" "$elapsed_ms" "$result_size" "$error" \
            >> "$OUTPUT"

        times+=("$elapsed_ms")
        last_status="$http_code"
        last_size="$result_size"
        last_error="$error"
        rm -f "$tmpfile"
        cumulative_ms=$(( cumulative_ms + elapsed_ms ))
        # A timeout/error won't get better on re-run — stop this query here.
        [[ "$http_code" != "200" ]] && break
    done

    # Compute median time over the runs actually executed
    n_times=${#times[@]}
    sorted_times=($(printf '%s\n' "${times[@]}" | sort -n))
    median_idx=$(( n_times / 2 ))
    median="${sorted_times[$median_idx]}"

    if [[ "$last_status" == "200" ]]; then
        printf "OK  %6d ms (median)  %s bytes\n" "$median" "$last_size"
        PASSED=$((PASSED + 1))
    elif [[ "$last_status" == "000" ]]; then
        printf "TIMEOUT after %ds\n" "$TIMEOUT"
        ERRORS=$((ERRORS + 1))
    else
        printf "FAIL  HTTP %s  %s\n" "$last_status" "${last_error:0:80}"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=== Results ==="
echo "  Passed:  $PASSED / $TOTAL"
echo "  Failed:  $FAILED / $TOTAL"
echo "  Errors:  $ERRORS / $TOTAL"

# Generate summary
SUMMARY="${OUTPUT%.tsv}_summary.tsv"
python3 "$SCRIPT_DIR/summarize.py" "$OUTPUT" > "$SUMMARY"

# Compute aggregate stats from summary (SPARQLoscope-style means)
if [[ $PASSED -gt 0 ]]; then
    python3 -c "
import csv, math, sys

times = []
with open('$SUMMARY') as f:
    for row in csv.DictReader(f, delimiter='\t'):
        if row['status'] == '200':
            times.append(float(row['median_ms']))

if not times:
    sys.exit(0)

n = len(times)
s = sorted(times)

arith = sum(times) / n
geo = math.exp(sum(math.log(max(t, 0.001)) for t in times) / n)
med = s[n // 2] if n % 2 == 1 else (s[n // 2 - 1] + s[n // 2]) / 2

# Penalized means (P=2, P=10): failures count as P * slowest passing query.
max_t = max(times)
n_fail = $FAILED + $ERRORS
penalized_2  = list(times) + [2 * max_t] * n_fail
penalized_10 = list(times) + [10 * max_t] * n_fail

arith_p2 = sum(penalized_2) / len(penalized_2)
geo_p2   = math.exp(sum(math.log(max(t, 0.001)) for t in penalized_2) / len(penalized_2))
geo_p10  = math.exp(sum(math.log(max(t, 0.001)) for t in penalized_10) / len(penalized_10))
med_p2   = sorted(penalized_2)[len(penalized_2) // 2]

print(f'  Arith Mean:        {arith:,.1f} ms  ({arith/1000:.2f} s)')
print(f'  Arith Mean (P=2):  {arith_p2:,.1f} ms')
print(f'  Median (P=2):      {med_p2:,.1f} ms')
print(f'  Geo Mean (P=2):    {geo_p2:,.1f} ms')
print(f'  Geo Mean (P=10):   {geo_p10:,.1f} ms')
print(f'  Total:             {sum(times):,.0f} ms')
"
fi

echo "  Output:  $OUTPUT"
echo "  Summary: $SUMMARY"
echo ""
echo "Compare against the published baseline:"
echo "  python3 summarize.py --diff baseline/summary.tsv $SUMMARY   # (see README)"
echo ""
