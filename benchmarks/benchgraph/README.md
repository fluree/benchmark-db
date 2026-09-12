# Pokec / Cypher — Fluree v4.2.1 benchmark results

> **Fluree can store and query graphs larger than RAM.** Fluree and Neo4j use disk-backed
> storage, so the entire database does not have to fit in memory. **Memgraph and FalkorDB,
> in the configurations benchmarked here, require the graph and its indexes to fit in RAM**,
> with additional memory needed for queries. Their durable logs and snapshots do not
> remove that requirement.

| Engines / tested configuration | What limits graph capacity? |
|---|---|
| **Fluree**, Neo4j — disk-backed storage | The database can exceed RAM; capacity depends on available storage and engine limits. Queries still need sufficient working memory. |
| Memgraph — in-memory transactional; FalkorDB — in-memory graph | The resident graph and indexes must fit in available RAM, alongside query and runtime overhead. |

This distinction concerns the **tested storage modes**. Memgraph also offers an
[on-disk transactional mode](https://memgraph.com/blog/memgraph-storage-modes-explained),
which is not measured here. See also
[Neo4j's disk/page-cache model](https://neo4j.com/docs/operations-manual/current/performance/memory-configuration/)
and [FalkorDB's in-memory architecture](https://www.falkordb.com/blog/graph-database-explained/).
All Pokec graphs in this run fit in the 64 GB host; these timings do not measure
performance after a graph outgrows RAM.

Fluree runner for [Memgraph's benchgraph](https://memgraph.com/benchgraph)
benchmark (formerly mgbench), the suite Memgraph uses for its published
vs-Neo4j comparison. Dataset: the Pokec social network — single `:User`
label, single `Friend` edge type, with query
categories: point lookups, aggregations, 1–4-hop expansions, variable-length
neighbourhoods, cyclic/long patterns, shortest paths, and small writes.

Query texts in `queries/` are the **verbatim Neo4j-portable branch** from
`memgraph/tests/mgbench/workloads/pokec.py` (vendored in `upstream/`). `query-set.tsv` maps each query to its
parameterization (`$id` / `$from`,`$to` sampling, per pokec.py) and
read/write kind.

## Results

**[→ Full report: Fluree v4.2.1 vs native Memgraph, Neo4j & FalkorDB](reports/pokec/REPORT.md)**
([raw per-engine TSVs](reports/pokec/engines/) · [per-query medians](reports/pokec/summary.tsv) ·
[durability verification](reports/pokec/engines/durability/) · [run metadata](reports/pokec/meta.json))

**Fluree v4.2.1 has the lowest geometric-mean latency for reads and durable writes at
all three scales.** At large (1.6 M nodes / 30.6 M edges), reads are **3.17–5.49× faster**
and durable writes **1.46–1.98× faster** than FalkorDB, Memgraph and Neo4j.

All four engines complete **35/35 queries at every scale** on one AWS `m7a.4xlarge`
(16 cores / 64 GB), with persistent client connections and per-commit durable writes.
The [durability traces](reports/pokec/engines/durability/) record flush syscalls in each
measured configuration. Completion means no execution errors; result-count differences
on two reads at small/medium scale are documented in the
[correctness notes](reports/pokec/REPORT.md#5-methodology--caveats).

![Pokec reads across three graph sizes: lower latency is faster](../../assets/pokec-reads-scaling.svg)

![Pokec durable writes across three graph sizes: lower latency is faster](../../assets/pokec-writes-scaling.svg)

Geometric mean, ms — lower is faster. Last three columns state how much faster (or slower)
Fluree is than each engine. **Bold = fastest in the row.**

**Durable writes** (8 queries; Fluree lowest geometric mean at every scale):

| scale | Fluree | Memgraph | Neo4j | FalkorDB | vs Memgraph | vs Neo4j | vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| small | **2.57** | 3.25 | 2.93 | 3.15 | 1.26× faster | 1.14× faster | 1.22× faster |
| medium | **2.82** | 3.70 | 3.56 | 3.62 | 1.31× faster | 1.26× faster | 1.28× faster |
| large | **3.39** | 5.45 | 6.70 | 4.94 | 1.61× faster | 1.98× faster | 1.46× faster |

**Read-only** (27 queries; Fluree lowest geometric mean at every scale):

| scale | Fluree | Memgraph | Neo4j | FalkorDB | vs Memgraph | vs Neo4j | vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| small | **0.77** | 1.54 | 3.38 | 0.88 | 1.99× faster | 4.37× faster | 1.14× faster |
| medium | **1.29** | 3.86 | 6.56 | 2.42 | 3.00× faster | 5.09× faster | 1.88× faster |
| large | **1.90** | 7.22 | 10.41 | 6.01 | 3.81× faster | 5.49× faster | 3.17× faster |

The read advantage over the next-fastest engine grows from **1.14× at small to 3.17×
at large**. At large, Fluree's five aggregate queries average **1.55 ms**, compared with
221–266 ms for the other engines (**143–172× faster**). Fluree also leads the
neighbourhood and shortest-path category geometric means at that scale.

Individual-query results show the limits of those averages. Fluree leads unfiltered
three- and four-hop expansion at large; FalkorDB leads the expansion category overall
(4.71 vs 6.45 ms) and point lookups (0.38 vs 0.57 ms). Neo4j's large `shortest_path`
advantage is small: **2.07 vs 2.19 ms, about 6% faster**. The larger write gaps are
`create__edge`, the 100-row batch insert, and `create__pattern` at large; full timings
and ratios are in the [per-query appendix](reports/pokec/REPORT.md#appendix--per-query-medians).

Measured September 11, 2026, using Fluree source build `0f26d9d6a`; the exact build and
configuration are recorded in [meta.json](reports/pokec/meta.json). These are single-client
latency measurements with the graphs fitting in RAM; they do not measure concurrent
throughput or performance beyond RAM capacity.

This replaces the July 2026 v4.1.2 results. Absolute times are not directly comparable:
the earlier run used `r8a.4xlarge` hardware and a new Fluree TCP connection per request.
**Correction to the previous report:** its Fluree writes were described as fsync-durable,
but that storage implementation did not fsync each commit. This run uses per-commit WAL
durability. See the [methodology](reports/pokec/REPORT.md#5-methodology--caveats) for details.

To reproduce the whole four-engine run on a box:
[`run-4engine-box.sh`](run-4engine-box.sh) → [`merge_runs.py`](merge_runs.py) →
[`gen_report.py`](gen_report.py); durability evidence with
[`verify-durability-box.sh`](verify-durability-box.sh).


## Reproduce the published HTTP measurements

Use the measured source build (`0f26d9d6a`) and a freshly imported Pokec ledger with
`FLUREE_STORAGE_FSYNC=wal` as described under Setup. The committed
[`params_small.json`](params_small.json), [`params_medium.json`](params_medium.json), and
[`params_large.json`](params_large.json) contain the exact draws shared by all four engines.
Small/medium use 2 warmups + 5 measured requests per query; large uses 1 + 3.

From this directory, with the small ledger running on port 8090:

```bash
mkdir -p results/http-small
# Each pass starts one client and reuses its HTTP connection across all requests.
for pass in reads1 reads2 full; do
  extra=()
  if [ "$pass" != full ]; then extra+=(--skip-writes); fi
  python3 bench_runner.py --engine fluree --host 127.0.0.1 --http-port 8090 \
    --ledger pokec --num-vertices 10000 --params-file params_small.json \
    --warmup 2 --runs 5 "${extra[@]}" \
    --output "results/http-small/small_fluree_${pass}.tsv" || exit 1
done
```

Run this loop in Bash. Discard `reads1`; take read rows from `reads2` and write rows
from `full`. Reads precede mutations. Reimport before another measurement sequence.
For medium change the vertex count to `100000` and use `params_medium.json`; for large
use `1632803`, `params_large.json`, `--warmup 1 --runs 3`, and matching output names.
The wrapper uses the same HTTP implementation, for example:

```bash
./run_benchmark.sh --num-vertices 10000 --params-file params_small.json \
  --warmup 2 --runs 5 --skip-writes --output results/http-small/manual-reads.tsv
```

To verify connection reuse locally without installing a database:

```bash
python3 -m unittest discover -s . -p 'test_http_keepalive.py'
```

This test uses a real HTTP/1.1 server to check read/write connection reuse, complete
response consumption, and failure handling without replaying a write.
For all four engines, dataset downloads, merging, and chart generation, follow the
[full reproduction instructions](reports/pokec/REPORT.md#6-reproduce-it).

## Setup

```bash
mkdir -p data
# 1. dataset — the Memgraph .cypher dump (small = 10k users / 121,716 edges; also medium, large)
curl -L -o data/pokec_small_import.cypher \
  https://s3.eu-west-1.amazonaws.com/deps.memgraph.io/dataset/pokec/benchmark/pokec_small_import.cypher

# 2. import the .cypher dump natively + serve over HTTP
#    fluree create --from *.cypher ingests the exact same file Memgraph/Neo4j load —
#    no Turtle conversion, no @vocab context; bare Cypher names resolve directly.
mkdir -p fluree-data && cd fluree-data
fluree init
fluree create pokec --from ../data/pokec_small_import.cypher
FLUREE_STORAGE_FSYNC=wal FLUREE_CYPHER_ALLOW_FULL_SCAN=1 \
  fluree server run --listen-addr 127.0.0.1:8090
```

Run the server in one terminal and the following commands from `benchmarks/benchgraph`
in another.

## Run

```bash
./run_benchmark.sh                       # full set, 3 runs + 1 warmup (wrapper over bench_runner.py)
./run_benchmark.sh -q 'arango__expansion*' -r 5
./run_benchmark.sh --skip-writes         # leave the ledger unmutated
./run_benchmark.sh --num-vertices 100000 # pokec medium id range
```

The runner ([`bench_runner.py`](bench_runner.py)) measures the published transports with
**persistent connections**. For Fluree, Python's standard-library `http.client.HTTPConnection`
is cached by host/port and reused for both query and update requests. Every response body
is fully read before the next request. No special flag or external HTTP load-testing tool is
needed: `--engine fluree` and the shell wrapper both use this path automatically. Bolt and
RESP use their native drivers' connection reuse. The optional Neo4j HTTP path below is a
separate diagnostic mode and is not used in the published comparison.

Timing starts before sending the request and ends after reading the full response body.
The first request opens the connection; the warmup absorbs that setup cost. A connection
error fails that sample and closes the connection; the next sample reconnects. Failed
requests are not replayed, since a write might have committed before its response was lost.
The runner exits nonzero if any query fails, including during warmup.

The old Fluree client opened a fresh TCP connection per request. A shell loop invoking
`curl` separately for each query also does that and does **not** reproduce these timings.

- **`--engine fluree`** — Cypher over Fluree's **HTTP/JSON API**. **This is what the
  published [Pokec report](reports/pokec/REPORT.md) uses for Fluree.**
- **`--engine memgraph` / `--engine neo4j`** — Cypher over **Bolt**, through the official
  neo4j driver (`auth=None`).
- **`--engine falkordb`** — Cypher over native **RESP `GRAPH.QUERY`** (`--redis-port 6379
  --graph <name>`), using the path-query overrides in
  [`queries-falkordb/`](queries-falkordb/); load its CSVs with
  [`cypher_to_csv.py`](cypher_to_csv.py) + `falkordb-bulk-insert` (see report §4/§6).

Transport is part of the delivered latency, so it is not normalised away. (A
`--engine fluree_bolt` path also exists for Bolt-surface testing, but the neo4j driver's
record deserialization dominates Fluree's large-result latency, so HTTP is the leaner,
representative Fluree client and the one behind the published numbers.) The query text and
semantics are identical across transports. Output TSV matches the other runners in this repo:
`query_id, description, run, status, time_ms, result_size, error`.

Write queries mutate the ledger; re-create it from the `.cypher` dump for a clean
timing run, or pass `--skip-writes`. Parameters are seeded and cached in
`--params-file` so every engine sees the same ids; `gen_report.py <engines-dir> <out-dir>`
rebuilds `summary.tsv` and the report tables from the per-engine raw TSVs.



Every measured query runs through Fluree's **Cypher** surface end to end — the
verbatim Neo4j query texts and Neo4j-style responses, over the HTTP API. **Load is Cypher
too:** Fluree ingests the upstream `.cypher` dump directly with
`fluree create --from file.cypher` — the exact same 131k-statement file Memgraph and
Neo4j load — so the whole pipeline, bulk load and every query, is Cypher with no format
conversion and no `@vocab` context (bare Cypher names resolve directly). Load stays out
of the measured path (the moral equivalent of `neo4j-admin import`).

## Comparison context

Memgraph publishes Neo4j numbers for this exact workload (isolated latency +
throughput, mixed, realistic modes) at
[memgraph.com/benchgraph](https://memgraph.com/benchgraph). Their harness is
Bolt-based. Rather than compare against those published numbers (different
hardware, multi-worker throughput), this runner **co-measures all four engines
locally on the same box**, each over its real-world client transport — Fluree over
HTTP, Memgraph and Neo4j over Bolt, FalkorDB over native RESP — with one persistent
connection per client, so hardware and connection model are held constant and every
engine is measured as its users would run it. See the
[Pokec report](reports/pokec/REPORT.md) for the full methodology and caveats.
