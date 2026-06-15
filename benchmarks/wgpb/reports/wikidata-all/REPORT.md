# WGPB benchmark — Fluree on the full Wikidata all-dump

> **Run 2026-06-12 on Fluree v4.0.6. All 850
> WGPB graph-pattern queries against the full 21.5B-triple Wikidata all-dump on a single AWS
> r7a.8xlarge (32 cores / 256 GB). 100% completion — 0 timeouts, 0 errors — with a 794 GB
> index that is 3× larger than RAM. 1 warmup + 3 runs, median per query (fractional-ms
> timings), 120 s timeout. 73.8% of queries under 100 ms; 97.1% under 1 s.**

The [Wikidata Graph Pattern Benchmark](https://zenodo.org/record/4035223) (WGPB, from
Hogan et al., *"A Worst-Case Optimal Join Algorithm for SPARQL"*, ISWC 2019) is 850 basic
graph pattern queries — 17 abstract join shapes × 50 predicate instantiations — designed to
stress join planning on cyclic and star patterns where binary join trees traditionally blow
up. Each query is `SELECT * ... LIMIT 1000` over Wikidata `prop/direct` truthy edges.

_Query results first; dataset/hardware/import detail in §3–§4. Raw per-query timings in
`engines/fluree.tsv` (all runs) and `engines/fluree_summary.tsv` (per-query medians)._

## 1. Aggregates

| metric | Fluree |
|---|---|
| completed | **850 / 850** (0 timeouts, 0 errors) |
| geo mean | **43 ms** |
| median | **33 ms** |
| arith mean | 182 ms |
| < 100 ms | 627 (**73.8%**) |
| < 500 ms | 785 (92.4%) |
| < 1 s | 825 (**97.1%**) |
| slowest query | 19.0 s (`TI2-48`) |

## 2. By category

17 families × 50 queries. Geo mean / median / arith mean of the per-query medians, plus the
slowest query in each family.

| family | shape | geo | median | mean | max | <1 s |
|---|---|--:|--:|--:|--:|--:|
| J3 | object-object join, 3 patterns | 68 ms | 66 ms | 101 ms | 661 ms | 50/50 |
| J4 | object-object join, 4 patterns | 88 ms | 107 ms | 147 ms | 1.3 s | 49/50 |
| P2 | path, length 2 | 27 ms | 25 ms | 40 ms | 202 ms | 50/50 |
| P3 | path, length 3 | 30 ms | 26 ms | 59 ms | 567 ms | 50/50 |
| P4 | path, length 4 | 68 ms | 46 ms | 395 ms | 5.1 s | 44/50 |
| S1 | directed 4-cycle (square) | 24 ms | 18 ms | 100 ms | 640 ms | 50/50 |
| S2 | bipartite square | 124 ms | 132 ms | 396 ms | 2.9 s | 44/50 |
| S3 | mixed-direction 4-cycle | 71 ms | 45 ms | 318 ms | 2.5 s | 45/50 |
| S4 | converging square | 66 ms | 50 ms | 287 ms | 1.6 s | 48/50 |
| T2 | subject out-star, 2 patterns | 16 ms | 14 ms | 19 ms | 147 ms | 50/50 |
| T3 | subject out-star, 3 patterns | 15 ms | 14 ms | 17 ms | 99 ms | 50/50 |
| T4 | subject out-star, 4 patterns | 17 ms | 15 ms | 21 ms | 108 ms | 50/50 |
| TI2 | object in-star, 2 patterns | 38 ms | 29 ms | 418 ms | 19.0 s | 49/50 |
| TI3 | object in-star, 3 patterns | 53 ms | 46 ms | 93 ms | 1.3 s | 49/50 |
| TI4 | object in-star, 4 patterns | 92 ms | 60 ms | 380 ms | 10.6 s | 48/50 |
| Tr1 | triangle | 34 ms | 25 ms | 122 ms | 688 ms | 50/50 |
| Tr2 | triangle (variant) | 44 ms | 39 ms | 181 ms | 1.2 s | 49/50 |

Every family — including the cyclic squares (S) and triangles (Tr) that WGPB was designed
to stress — runs at a double-digit-millisecond geo mean except S2 (124 ms); every
family keeps ≥44 of 50 queries under 1 s. The remaining tail is two object in-star
stragglers (`TI2-48`, `TI4-33` — hash-heuristic misfires on extreme-cardinality
predicates) and the long-path P4 band.

### Slowest 10 queries

| query | median |
|---|--:|
| `TI2-48` | 19.0 s |
| `TI4-33` | 10.6 s |
| `P4-03` | 5.1 s |
| `P4-23` | 3.1 s |
| `TI4-44` | 3.0 s |
| `S2-38` | 2.9 s |
| `S3-05` | 2.5 s |
| `P4-35` | 2.2 s |
| `P4-02` | 2.0 s |
| `S2-16` | 1.7 s |

## 3. Dataset and import

| | |
|---|---|
| dataset | Wikidata all-dump (`latest-all.nt.gz`), snapshot dated 2026-06-04 |
| size | 250,036,308,745 bytes compressed (~3 TB uncompressed N-Triples) |
| triples | **21,512,007,172** |
| unique predicates | 62,901 |
| import | 6,785 gzip shards, `--parallelism 32`, wall **6 h 44 m** (0.89 M triples/s avg) |
| index size | 794 GB |
| import peak memory | 109 GB RSS (no swap) |

The dump was resharded into 6,785 `.nt.gz` shards (the multi-member gzip of the original
single file is not chunkable for parallel import) and imported on the same 256 GB box used
for queries.

## 4. Hardware and methodology

| | |
|---|---|
| instance | AWS r7a.8xlarge — 32 cores AMD EPYC (Zen 4), 256 GB RAM |
| disk | 3 TB gp3 (16,000 IOPS / 1,000 MB/s) |
| OS | Ubuntu 24.04 |
| engine | Fluree v4.0.6 |
| protocol | HTTP SPARQL endpoint, `Accept: text/tab-separated-values` |
| runs | 1 warmup + 3 timed runs per query; per-query metric = median |
| timeout | 120 s (no query hit it) |

Note the working set does not fit in RAM: the 794 GB index is ~3× the box's 256 GB, so
queries run with a partially cold cache throughout (the warmup run absorbs most first-touch
I/O for each query's predicates). Query cache budget was 35% of RAM.
