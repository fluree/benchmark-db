# benchgraph (Memgraph vs Neo4j vs FalkorDB) — Pokec on Fluree Cypher

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

## Setup

```bash
# 1. dataset — the Memgraph .cypher dump (small = 10k users / 121,716 edges; also medium, large)
curl -L -o data/pokec_small_import.cypher \
  https://s3.eu-west-1.amazonaws.com/deps.memgraph.io/dataset/pokec/benchmark/pokec_small_import.cypher

# 2. import the .cypher dump natively + serve over HTTP
#    fluree create --from *.cypher ingests the exact same file Memgraph/Neo4j load —
#    no Turtle conversion, no @vocab context; bare Cypher names resolve directly.
mkdir -p fluree-data && cd fluree-data
fluree init
fluree create pokec --from ../data/pokec_small_import.cypher
FLUREE_CYPHER_ALLOW_FULL_SCAN=1 fluree server start --listen-addr 127.0.0.1:8090
```

## Run

```bash
./run_benchmark.sh                       # full set, 3 runs + 1 warmup
./run_benchmark.sh -q 'arango__expansion*' -r 5
./run_benchmark.sh --skip-writes         # leave the ledger unmutated
./run_benchmark.sh --num-vertices 100000 # pokec medium id range
```

The runner ([`bench_runner.py`](bench_runner.py)) measures each engine over the transport
its users actually use:

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
timing run, or pass `--skip-writes`.

## Results

**[→ Full report: Fluree v4.1.2 vs native Memgraph, Neo4j & FalkorDB](reports/pokec/REPORT.md)**
([raw per-engine TSVs](reports/pokec/engines/) · [per-query medians](reports/pokec/summary.tsv) ·
[run metadata](reports/pokec/meta.json))

All four engines answer **35/35 at every scale** on one AWS `r8a.4xlarge`, and return
**byte-identical result sets**. This is a **read _and_ write** benchmark, so writes lead.
All four are held to the **same per-commit durability contract** (every commit fsynced) —
Memgraph's *published* sub-millisecond writes use a non-durable mode that acks before disk,
which no database of record would run on, so it is excluded here.

Geometric mean, ms — lower is faster. Last three columns state how much faster (or slower)
Fluree is than each engine. **Bold = fastest in the row.**

**Durable writes** (Fluree wins outright at every scale):

| scale | Fluree | Memgraph | Neo4j | FalkorDB | vs Memgraph | vs Neo4j | vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| small | **1.32** | 3.03 | 1.76 | 2.93 | 2.30× faster | 1.33× faster | 2.22× faster |
| medium | **1.27** | 3.39 | 2.94 | 3.36 | 2.66× faster | 2.31× faster | 2.64× faster |
| large | **1.73** | 4.46 | 4.07 | 4.57 | 2.57× faster | 2.35× faster | 2.63× faster |

**Read-only** (Fluree fastest at every scale):

| scale | Fluree | Memgraph | Neo4j | FalkorDB | vs Memgraph | vs Neo4j | vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| small | **0.60** | 0.93 | 1.43 | 0.61 | 1.56× faster | 2.39× faster | 1.02× faster |
| medium | **1.23** | 2.36 | 4.99 | 1.75 | 1.92× faster | 4.05× faster | 1.42× faster |
| large | **1.47** | 4.41 | 6.80 | 4.57 | 3.01× faster | 4.64× faster | 3.12× faster |

**Writes:** Fluree's durable per-commit path is **2.3–2.7× faster than Memgraph and FalkorDB
and 1.3–2.4× faster than Neo4j** at every scale. **Reads:** Fluree is the **fastest engine at
every scale** (**1.6–3.0× faster** than Memgraph, **2.4–4.6×** than Neo4j, **1.0–3.1×** than
FalkorDB — tied with FalkorDB on the tiny small graph, pulling away with scale). The blend
hides a **division of strengths**: Fluree wins the analytical half (whole-graph aggregates
~O(1) via index directories, **100–720× faster** than the scanners at large), while
**FalkorDB keeps a narrow traversal edge** (fixed-hop expansion/neighbourhood **~1.2–1.5×**
faster on the category geo-mean, down from ~2–3× in prior builds) — though **Fluree now
overtakes it on the deepest hops** (`expansion_3`, `expansion_4`) at large. Memgraph is the
balanced in-memory generalist (shortest-path leader at small/medium); Neo4j is slowest.
Note: this big-box run does not exercise **memory-bound scaling** — the in-memory engines
(FalkorDB, Memgraph) hold the whole graph in RAM, Fluree is disk-backed. See the report §2
and [`FLUREE-GAPS.md`](FLUREE-GAPS.md) for the open traversal targets.


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
HTTP, Memgraph and Neo4j over Bolt, FalkorDB over native RESP — so hardware is held
constant and every engine is measured as its users would run it. See the
[Pokec report](reports/pokec/REPORT.md) for the full methodology and caveats.
