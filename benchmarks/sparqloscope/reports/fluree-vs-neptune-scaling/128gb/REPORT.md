# Fluree vs Amazon Neptune @ 128 GB — DBLP-core head-to-head

> **The fair-fight size.** Neptune is non-functional below 128 GB (10–16/105 — mostly
> OOM/timeout); **128 GB is where it becomes usable (81/105)** and is the smallest matched
> instance at which both engines actually run the suite. This report is the per-query
> head-to-head *at that size*. For how the pair behaves across 32/64/128/256 GB, see the
> [scaling REPORT](../REPORT.md).

**Run 2026-06-26.** DBLP-core = **561,544,658 distinct triples**. Matched AWS Graviton4:
Fluree v4.1.0 on `r8g.4xlarge` (16c/128 GB, native install); Neptune 1.4.7.0 on
`db.r8g.4xlarge` (16c/128 GB), queried from an in-VPC client. SPARQLoscope 105-query suite,
1 warmup + median of 3, **180 s** per-query budget (Neptune `neptune_query_timeout` raised to
180 s to match), result cache off.

## TL;DR

- **Fluree 105/105 · 18.0 ms geomean. Neptune 81/105 · 6,536 ms geomean** (passed-only).
- On the **81 queries both engines complete**, Fluree's geomean is **13.3 ms vs Neptune's
  6,536 ms — 492× faster**.
- **Fluree loaded 8.7× faster** (449 s vs 3,893 s) — and loaded the raw file; Neptune's bulk
  loader **rejects blank nodes** (~42 % of DBLP-core), so its data had to be skolemized first.
- **Neptune fails 24 queries** even at 128 GB — the entire `EXISTS`/`MINUS`/`OPTIONAL` 3-way
  join families, three `COUNT`-style aggregates, `GROUP_CONCAT`, and two `UNION`s — almost all
  by hitting the 180 s timeout. Fluree answers all 24 (median 0.4 ms – 2.6 s).

## 1. Load

| | Fluree | Neptune | Fluree advantage |
|---|---|---|---|
| Load time | **449 s** | 3,893 s | **8.7× faster** |
| Throughput | **1.25 M tr/s** | 144 K tr/s | 8.7× |
| Input | raw N-Triples | **skolemized** (blank nodes rejected) | — |
| Parse/insert errors | 0 | 0 (after skolemization) | — |

## 2. Query suite (105 queries)

| | Fluree | Neptune |
|---|---|---|
| Passed | **105 / 105** | 81 / 105 |
| Failed | 0 | **24** (22 timeout, 2 error) |
| Geomean (own passed set) | **18.0 ms** | 6,536 ms |
| Geomean on the 81 shared queries | **13.3 ms** | 6,536 ms → **492×** |

### On the queries Neptune *does* answer, Fluree is 4×–95,000× faster

Even excluding every Neptune failure, the gap on shared queries is enormous:

| query | Fluree | Neptune | Neptune ÷ Fluree |
|---|---|---|---|
| `number-of-subjects` | 1.5 ms | 145,420 ms | **95,420×** |
| `join-2-large-large` | 0.6 ms | 41,644 ms | 73,447× |
| `number-of-triples` | 0.5 ms | 32,635 ms | 71,256× |
| `group-by-implicit-string-max` | 0.6 ms | 43,727 ms | 70,869× |
| `group-by-implicit-numeric-min` | 0.5 ms | 13,521 ms | 27,937× |
| `distinct-count-object-low-multiplicity` | 0.5 ms | 9,495 ms | 18,544× |

And Neptune's **best-case** cells — the handful where it comes closest — are still multiples slower:

| query | Fluree | Neptune | Neptune ÷ Fluree |
|---|---|---|---|
| `join-xlarge-star-on-small-predicates` | 2.0 ms | 32.5 ms | 16.6× |
| `result-size-tiny` | 2.4 ms | 30.9 ms | 13.0× |
| `result-size-large` | 671 ms | 2,881 ms | 4.3× |
| `result-size-xlarge` | 6,798 ms | 29,228 ms | 4.3× |

Neptune never beats Fluree on a single one of the 105 queries.

### The 24 queries Neptune fails at 128 GB

All time out at 180 s (`early-abort` / warmup timeout) except two `Operation terminated` (500):

| family | count | queries |
|---|---|---|
| `exists-join-*` | 7 | 2-large-large-with-large-result, 3-chain-1/2, 3-star-1/2, large-large, large-small |
| `minus-join-*` | 7 | 2-large-large-with-large-result, 3-chain-1/2, 3-star-1/2, large-large, large-small |
| `optional-join-*` | 4 | 3-chain-2, 3-star-2, large-large, large-small (500) |
| `number-of-*` | 3 | blank-nodes, literals, objects |
| `group-by-string-groupconcat` | 1 | |
| `union-*` | 2 | constraint-filter-restrictive (500), no-constraint |

Fluree completes every one of these: e.g. `exists-join-large-small` 0.8 ms, `minus-join-large-small`
0.7 ms, `number-of-literals` 0.4 ms, `number-of-objects` 1.6 ms, `optional-join-large-large` 149 ms,
`union-no-constraint` 0.6 ms — the anti-join / negation / union families that Neptune cannot finish
here are sub-millisecond to sub-second on Fluree.

## 3. Why 128 GB is the honest comparison point

Below 128 GB Neptune mostly OOMs (16/105 @ 32 GB, 10/105 @ 64 GB); above it the curve is flat
(84/105 @ 256 GB — only +3, and the same ~7 s geomean). **128 GB is the first size Neptune is
usable, so it's the fairest single-size head-to-head** — and even here Fluree completes 24 more
queries and is ~360–490× faster on the geomean. More RAM buys Neptune *completion*, never *speed*:
the queries it finishes run the same latency at 128 GB and 256 GB.

## Files
- `comparison_128gb.tsv` — per-query join (fluree vs neptune status/ms/ratio/outcome) for all 105.
- `fluree/fluree_summary.tsv`, `neptune/neptune_summary.tsv` — per-query median/min/max.
- `fluree/fluree_load.json`, `neptune/neptune_load.json` — load timings.
- Cross-size context: [`../REPORT.md`](../REPORT.md).
