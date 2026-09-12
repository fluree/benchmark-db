#!/usr/bin/env bash
#
# Run the Memgraph benchgraph Pokec query set against a running Fluree server
# over the Cypher HTTP surface. Thin wrapper over bench_runner.py --engine fluree,
# which holds ONE keep-alive HTTP connection for the whole run (the Bolt and RESP
# clients used for the other engines hold theirs too). The previous curl-per-query
# loop paid a fresh TCP connect on every request — ~0.25 ms on an m7a.4xlarge,
# more than the engine spends on a point lookup — so it is gone.
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
#   --params-file FILE   Shared params cache (default: params_<num-vertices>_seed<seed>_n<total>.json
#                        next to this script) so every engine sees the same ids
#   --skip-writes        Skip kind=write queries (leave the ledger unmutated)
#
# Parameterization follows pokec.py: $id / $from / $to are sampled uniformly
# from [1, num-vertices] ($from != $to), single_vertex_write samples from
# [1, 10*num-vertices]. Sampling is seeded and cached in the params file, so a
# given (seed, query set, runs) is reproducible and shared across engines.
#
# NOTE: write queries mutate the ledger. For a clean re-run, re-create the
# ledger from the .cypher import (or use --skip-writes).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

HOST="localhost"; PORT="8090"; LEDGER="pokec"; RUNS=3; WARMUP=1; OUTPUT=""
QUERY_PATTERN="*"; TIMEOUT=120; SEED=42; NUM_VERTICES=10000; PARAMS=""; SKIP_WRITES=""

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
        --params-file)   PARAMS="$2"; shift 2 ;;
        --skip-writes)   SKIP_WRITES="--skip-writes"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if ! curl -s -o /dev/null -w "%{http_code}" "http://${HOST}:${PORT}/health" | grep -q "200"; then
    echo "ERROR: Fluree server not reachable at http://${HOST}:${PORT}"
    exit 1
fi

mkdir -p "$RESULTS_DIR"
[[ -n "$OUTPUT" ]] || OUTPUT="$RESULTS_DIR/benchmark_$(date +%Y%m%d_%H%M%S).tsv"
[[ -n "$PARAMS" ]] || PARAMS="$SCRIPT_DIR/params_${NUM_VERTICES}_seed${SEED}_n$((RUNS + WARMUP)).json"

echo "=== benchgraph Pokec (Fluree Cypher runner, keep-alive HTTP) ==="
echo "  Server:     http://${HOST}:${PORT}  ledger ${LEDGER}"
echo "  Runs:       $RUNS (+ $WARMUP warmup)   Timeout: ${TIMEOUT}s"
echo "  Vertices:   $NUM_VERTICES   Seed: $SEED   Params: $PARAMS"
echo "  Output:     $OUTPUT"
echo ""

exec python3 "$SCRIPT_DIR/bench_runner.py" --engine fluree --host "$HOST" --http-port "$PORT" \
    --ledger "$LEDGER" --runs "$RUNS" --warmup "$WARMUP" --timeout "$TIMEOUT" --seed "$SEED" \
    --num-vertices "$NUM_VERTICES" --params-file "$PARAMS" --query-glob "$QUERY_PATTERN" \
    $SKIP_WRITES --output "$OUTPUT"
