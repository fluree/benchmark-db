# BSBM benchmark — 100M (headline)

> **Run 2026-06-12, Fluree v4.0.6 on the
> AWS m7a.4xlarge box (16c / 64 GB).** Real BSBM: bsbmtools-0.2
> `testdriver` randomized query mix → **QMpH** (query mixes/hour, higher = faster).
> Explore + Business Intelligence use cases × {1,4,8,16,32} clients. Engine-vs-engine
> on one box; not bit-comparable across toolkit versions/scales.

**Dataset:** BSBM 100M, pc=284826, `-fc` forward-chained → **100,000,748 triples** ·
**Engine:** Fluree v4.0.6 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

## 1. Explore (12 read queries) — QMpH

Near-linear scaling to the box's 16 physical cores, then plateau (c16→c32). **0 timeouts.**

| clients | QMpH |
|--------:|-----:|
| 1  | 7,585   |
| 4  | 36,677  |
| 8  | 65,347  |
| 16 | 99,772  |
| 32 (peak) | 108,726 |

Per-query AQET (c1, single-client latency) is **1–66 ms** across the mix (Q9 1.2 ms,
Q5 66 ms); Explore is point/star-lookup work and stays sub-100 ms at 100M.

## 2. Business Intelligence (8 analytic queries) — QMpH

| clients | QMpH | timeouts |
|--------:|-----:|:--:|
| 1  | 28.7 | 0 |
| 4  | 68.7 | 0 |
| 8  | 88.6 | 0 |
| 16 | 89.4 | 0 |
| 32 | 91.7 | 0 |

Every BI cell completes with **0 timeouts** across the client grid.

**Why BI QMpH looks low:** the driver's random parameter draw frequently selects the
**root product type `ProductType1`, which `-fc` forward chaining makes match *every*
product** → the analytic queries degrade to full scans/aggregations over all ~5.7M
offers / ~2.85M reviews. Per-query AQET (c1) shows the long poles are exactly those
root-type analytics: **Q4 35.5 s, Q8 19.6 s, Q5 15.4 s, Q3 8.5 s, Q1 7.1 s**; the
selective queries are fast (Q2 0.12 s, Q6 0.88 s, Q7 2.4 s). On leaf product types
these same queries run in seconds. This is a **generator/methodology artifact, not an
engine ceiling** — to get a fair BI-at-scale number, exclude the root type from the
param pool or regenerate without `-fc`.

## Files

- `runs/{explore,bi}__c{1,4,8,16,32}.xml` — raw driver `benchmark_result.xml`
- `querymix_summary.tsv` — per-cell QMpH / mix time / timeouts
- `per_query.tsv` — per-(cell, query) AQET / QpS / avg results
- aggregate grid: `../v406-summary.tsv`
