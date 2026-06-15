# BSBM benchmark — 1M (harness validation)

> **Run 2026-06-12, Fluree v4.0.6 on the
> AWS m7a.4xlarge box (16c / 64 GB).** Real BSBM: bsbmtools-0.2
> `testdriver` randomized query mix → **QMpH** (query mixes/hour, higher = faster).
> All three use cases — Explore, Business Intelligence, Explore-and-Update —
> × {1,4,8,16,32} clients. **0 timeouts across the entire grid.**

**Dataset:** BSBM 1M, pc=2785, `-fc` forward-chained → **724,101 triples** ·
**Engine:** Fluree v4.0.6 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

1M is the **harness-validation scale** — it fits entirely in cache, so it isolates
per-query overhead (parse/plan/serialize) from I/O. Headline numbers are at
[100M](../bsbm-100m/REPORT.md) and [200M](../bsbm-200m/REPORT.md).

## 1. Explore (12 read queries) — QMpH

| clients | QMpH |
|--------:|-----:|
| 1  | 38,540  |
| 4  | 133,141 |
| 8  | 223,571 |
| 16 | 298,676 |
| 32 (peak) | 297,955 |

1M is fully cached, so scan/I/O is near-free and per-query overhead (parse/plan/
serialize) dominates. Per-query AQET is sub-millisecond across the mix, and throughput
scales near-linearly to the 16-core box before plateauing at c16→c32.

## 2. Business Intelligence (8 analytic queries) — QMpH

| clients | QMpH |
|--------:|-----:|
| 1  | 2,993  |
| 4  | 9,985  |
| 8  | 16,719 |
| 16 | 24,768 |
| 32 (peak) | 24,784 |

At 1M every BI query is fast (all sub-0.35 s, even the root-type draws), so BI scales
cleanly with concurrency. The root-type (`ProductType1`) full-scan penalty only bites
at 100M+ (see the 100M report).

## 3. Explore-and-Update (interleaved SPARQL Update) — QMpH

| clients | QMpH |
|--------:|-----:|
| 1  | 3,338 |
| 4  | 5,587 |
| 8  | 6,913 |
| 16 | 6,419 |
| 32 | 6,520 |

Multi-client update works with **0 errors / 0 timeouts**. Update QMpH plateaus past ~c8
because writes are queue-serialized while the interleaved reads parallelize — expected
for a serialized commit path. The update use case runs against the `bsbm1mupd` ledger
(which carries ~14k extra triples from prior update runs).

## Files

- `runs/{explore,bi,update}__c{1,4,8,16,32}.xml` — raw driver `benchmark_result.xml`
- `querymix_summary.tsv`, `per_query.tsv`
- aggregate grid: `../v406-summary.tsv`
