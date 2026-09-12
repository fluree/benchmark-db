# benchmark-db

**Fluree is a multi-modal database with an RDF foundation, supporting SPARQL, Cypher,
GraphQL, and Fluree JSON-LD query.**
This repository contains reproducible benchmarks for [Fluree](https://labs.flur.ee)
and other engines, with datasets, hardware, versions, raw timings and setup commands.

| RDF / SPARQL · [DBLP-core](benchmarks/sparqloscope/reports/dblp-core/REPORT.md) | Property graph / Cypher · [Pokec](benchmarks/benchgraph/reports/pokec/REPORT.md) |
|---|---|
| **11.5× faster than QLever · 17.1× faster than Virtuoso** | **3.17–5.49× faster reads · 1.46–1.98× faster durable writes** than FalkorDB, Memgraph and Neo4j |
| Fluree **v4.2.0** · 561 M triples · **105/105 queries complete** | Fluree **v4.2.1** · 1.6 M nodes / 30.6 M edges · **35/35 queries complete** |
| **17.5 ms** penalized geometric-mean latency (P=2) | **1.90 ms reads · 3.39 ms durable writes**, geometric means at large scale |

Each comparison uses its own workload and protocol; timings are comparable within a
benchmark. **All charts below show latency: lower is faster.** Per-query results and
correctness notes accompany each report.

## RDF / SPARQL — DBLP-core: 7 engines, matched hardware

**Fluree v4.2.0 answers all 105 queries with a 17.5 ms geometric mean** on
561 million triples. QLever averages 202.4 ms and Virtuoso 299.7 ms—**11.5× and
17.1× Fluree's latency**, respectively. All seven engines use matching AWS
`m7a.4xlarge` hardware (16 cores / 64 GB).

![DBLP-core geometric-mean query time, all 7 engines on matched hardware; lower is faster](assets/dblp-core-geomean.svg)

| metric | **Fluree v4.2.0** | QLever | Virtuoso | MillenniumDB | Jena | Oxigraph | Blazegraph |
|---|---|---|---|---|---|---|---|
| **queries passed** | **105/105** | 105/105 | 103/105 | 103/105 | 34/105 | 39/105 | 3/105 |
| **geo mean (P=2)** | **17.5 ms (1.0×)** | 202.4 ms (11.5×) | 299.7 ms (17.1×) | 1,664.2 ms (94.9×) | 67.7 s (3859.8×) | 87.0 s (4965.6×) | 332.9 s (18990.3×) |

_Geometric mean uses all 105 queries; failures count as 2× the 180-second timeout
(SPARQLoscope P=2). Lower is faster. The full report includes P=10 and per-query results._

→ **[Full DBLP-core report](benchmarks/sparqloscope/reports/dblp-core/REPORT.md)** ·
[per-engine raw TSVs](benchmarks/sparqloscope/reports/dblp-core/engines/) ·
[run metadata & setup facts](benchmarks/sparqloscope/reports/dblp-core/meta.json)

Fluree: official v4.2.0 binary, measured September 7, 2026. Other engines:
June 11, 2026, on the same instance class and dataset.
[Reproduce the Fluree run](benchmarks/sparqloscope/reports/dblp-core/v420-release/REPORT.md).

## Property graph / Cypher — Pokec: reads and durable writes

> **Capacity matters: Fluree and Neo4j can store and query databases larger than RAM.**
> The Memgraph and FalkorDB configurations tested here keep the graph and indexes in RAM,
> so their capacity is bounded by available memory. Disk capacity and query memory still
> impose limits on disk-backed engines. See the [storage-mode comparison](benchmarks/benchgraph/README.md)
> for details, including Memgraph's separate on-disk mode, which was not tested.

**3.17–5.49× faster reads and 1.46–1.98× faster durable writes** on Pokec's
1.6 million nodes and 30.6 million edges, compared with FalkorDB, Memgraph and Neo4j.
Fluree has the lowest geometric-mean latency for both reads and writes at all three
measured scales. All four engines run on one AWS `m7a.4xlarge` (16 cores / 64 GB).

![Pokec reads across three graph sizes: Fluree v4.2.1 has the lowest geometric-mean latency at each scale; lower is faster](assets/pokec-reads-scaling.svg)

![Pokec durable writes across three graph sizes: Fluree v4.2.1 has the lowest geometric-mean latency at each scale; lower is faster](assets/pokec-writes-scaling.svg)

Geometric means of per-query medians: **27 reads and 8 writes**, measured separately
with persistent client connections. Every engine uses per-commit durable writes;
[syscall traces](benchmarks/benchgraph/reports/pokec/engines/durability/) document the
configured flush behavior. All 35 queries complete on every engine at every scale;
completion does not imply identical results. The
[report's correctness notes](benchmarks/benchgraph/reports/pokec/REPORT.md#5-methodology--caveats)
detail differences on two read queries at small/medium scale. Some individual queries
favor other engines; for example, Neo4j's large-scale `shortest_path` is about 6%
faster (2.07 vs 2.19 ms).

→ **[Full Pokec report](benchmarks/benchgraph/reports/pokec/REPORT.md)** ·
[results at all three scales & reproduction](benchmarks/benchgraph/README.md) ·
[raw timings](benchmarks/benchgraph/reports/pokec/engines/) ·
[run metadata](benchmarks/benchgraph/reports/pokec/meta.json)

Measured September 11, 2026, using Fluree source build `0f26d9d6a`.

## Other benchmarks

These are separate measurements; each report records its own engine versions, hardware
and configuration. WGPB was measured September 12, 2026, using Fluree v4.2.1;
Wikidata-truthy uses its separately documented run.

| Benchmark | Dataset | Fluree completed | Fluree geometric mean | Comparison |
|---|---|---:|---:|---|
| [Wikidata-truthy / SPARQLoscope](benchmarks/sparqloscope/reports/wikidata-truthy/REPORT.md) | 8.19 B triples | 105/105 | 367.4 ms | QLever: 10.4× the latency |
| [Wikidata Graph Pattern Benchmark — Fluree v4.2.1](benchmarks/wgpb/reports/wikidata-all/REPORT.md) | 21.127 B distinct triples | 850/850 | 20.165 ms | Fluree only |

WGPB uses the full Wikidata all-dump: 21.512 billion input records reconcile to
21.127 billion distinct triples. The run used one warmup and three measured HTTP
requests per query on an AWS `r7a.8xlarge` (32 vCPU / 256 GiB); 99.2% of per-query
medians were under one second, with no errors or timeouts.
[Raw timings and validation evidence](benchmarks/wgpb/reports/wikidata-all/evidence/README.md)
accompany the report.

SPARQLoscope uses the penalized P=2 mean. The graph-pattern and Cypher benchmarks
use their own query sets and protocols; values are comparable within each benchmark.

## Reproduce DBLP-core

On Ubuntu 24.04 x86_64, with curl, pigz, Python 3, coreutils and xz-utils installed:

```bash
bash benchmarks/sparqloscope/reproduce-dblp-fluree.sh /path/to/new-run
```

The script installs the pinned v4.2.0 binary, verifies binary and dataset checksums,
imports a fresh ledger, runs all 105 queries, and saves timings and responses.
See the [run instructions](benchmarks/sparqloscope/reports/dblp-core/v420-release/REPORT.md)
for hardware requirements. Dataset sources are pinned under
[SPARQLoscope datasets](benchmarks/sparqloscope/datasets/), with copies in
`s3://fluree-benchmark-data/`.

To regenerate the DBLP report and SVG from the committed timing TSVs:

```bash
python3 common/generate_report.py benchmarks/sparqloscope/reports/dblp-core
python3 -c 'from common.make_charts import make_dblp_chart; make_dblp_chart()'
```

- [Native engine setup](common/engine-setup/)
- [SPARQL query runner](common/run_benchmark.sh): warmup, timed requests, timeout, saved responses.
- [Report generator](common/generate_report.py): aggregate, category and per-query comparisons.
- [DBLP chart generator](common/make_charts.py) and [Pokec line-chart generator](benchmarks/benchgraph/reports/pokec/make_scaling_charts.py): charts read the published TSVs and version metadata.

## Method

DBLP uses one warmup followed by the median of three measured requests per query,
with a 180-second timeout. HTTP timings include response transfer. Other engines'
protocol differences, including single-run or cold-cache measurements, are recorded
in the full report. Matched instance hardware does not eliminate host variation.

The DBLP and Wikidata query sets come from
[SPARQLoscope](https://github.com/ad-freiburg/sparqloscope). The property-graph suite
uses [benchgraph](https://memgraph.com/benchgraph) queries over Pokec, through
Fluree's HTTP Cypher endpoint and the other engines' native client protocols.

## Repository layout

- `benchmarks/sparqloscope/`: query sets, pinned datasets and multi-engine reports.
- `benchmarks/wgpb/`: 850 Wikidata graph-pattern queries and results.
- `benchmarks/benchgraph/`: Cypher/Pokec runner, queries and results.
- `common/`: SPARQL runner, report/chart generators and engine setup.
- `assets/`: generated SVG charts.
