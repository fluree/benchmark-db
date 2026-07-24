# Fluree vs Amazon Neptune — DBLP-core, across instance sizes

> **Run 2026-06-26.** SPARQLoscope (105 SPARQL-1.1 queries) + dataset load, **Fluree v4.1.0
> vs Amazon Neptune 1.4.7.0**, on **matched AWS Graviton4 (`r8g`) instances at four sizes**:
> 32, 64, 128, 256 GB (8 GB/vCPU). Unlike the same-box [`dblp-core`](../dblp-core/REPORT.md)
> run (7 engines, one box), this run holds the *engine pair* fixed and **scales the hardware**
> to find where — if anywhere — Neptune becomes competitive. DBLP-core = **561,544,658
> distinct triples** (574.2 M raw N-Triples lines, ~2.2 % exact dups removed). 1 warmup +
> median of 3, 180 s per-query timeout, result cache off.

> **See also:** [`128gb/REPORT.md`](128gb/REPORT.md) — the focused per-query head-to-head at
> **128 GB**, the smallest size where Neptune is functional (81/105) and thus the fairest
> single-size comparison.

## TL;DR

- **Fluree passes 105/105 at every size**, 16.6–26.7 ms geomean, and loads 9–15× faster.
- **Neptune is non-functional below 128 GB** (10–16/105) and only becomes usable at **128 GB
  (81/105)** — then **plateaus** (256 GB only adds +3 → 84/105). ~21 queries never pass at any size.
- **More RAM buys *completion*, not *speed***: queries Neptune completes run the same time at
  32 GB and 256 GB; extra RAM only rescues queries from OOM/timeout. Even at 256 GB, Neptune's
  geomean is **7,587 ms vs Fluree's 16.6 ms (~460×)**.
- **Neptune can't ingest DBLP-core as-is** — its bulk loader rejects blank nodes (~42 % of
  triples); we skolemized `_:label`→IRI as preprocessing. Fluree loaded the raw file natively.

---

## 1. Load

| Instance | Fluree load | Fluree throughput | Neptune load | Neptune throughput |
|---|---|---|---|---|
| `r8g.xlarge` 4c/32 GB | **861 s** | **652 K tr/s** | 13,086 s | 43 K tr/s |
| `r8g.2xlarge` 8c/64 GB | **711 s** | **790 K tr/s** | 6,259 s | 90 K tr/s |
| `r8g.4xlarge` 16c/128 GB | **449 s** | **1.25 M tr/s** | 3,893 s | 144 K tr/s |
| `r8g.8xlarge` 32c/256 GB | **421 s** | **1.33 M tr/s** | — ¹ | — ¹ |

¹ The 256 GB Neptune cluster was resized in-place from the 128 GB cluster (data preserved),
so its load was not re-measured. Neptune load throughput scales ~linearly with size but stays
**9–15× behind Fluree** at every measured tier. Fluree throughput flattens past 16 cores
(I/O-bound), peaking at **1.33 M triples/s**.

**Preprocessing:** Neptune additionally required **skolemization** of the ~42 % blank-node
triples (a one-time ~15 min `sed`, reused across all tiers) before it could load at all.
Fluree required none.

---

## 2. Query benchmark (105 queries, 180 s budget)

| Instance | Fluree passed | Fluree geomean | Neptune passed | Neptune geomean (passed) | Neptune P=2 geomean |
|---|---|---|---|---|---|
| 4c/32 GB | **105/105** | **26.7 ms** | 16/105 | 9,895 ms | 208,187 ms |
| 8c/64 GB | **105/105** | **21.7 ms** | 10/105 | 15,133 ms | 266,207 ms |
| 16c/128 GB | **105/105** | **18.0 ms** | 81/105 | 6,536 ms | 16,341 ms |
| 32c/256 GB | **105/105** | **16.6 ms** | 84/105 | 7,587 ms | 16,417 ms |

_P=2 geomean is the SPARQLoscope penalized aggregate (a failed query counts as 2× the 180 s
timeout). "geomean (passed)" averages only completed queries, flattering the engine with more
failures._

### The crossover, plainly
Neptune's pass-count vs RAM: **16 → 10 → 81 → 84**. The jump is entirely **64→128 GB**
(10 → 81); below that Neptune OOMs/times-out on most of the suite, and above it the curve is
flat (**+3 from 128→256 GB**). A core group — `exists-join-3-chain-*`, `exists-join-3-star-*`,
`exists-join-2-large-large-with-large-result`, and similar — **times out at every size**; RAM
never rescues them.

### RAM buys completion, not speed
Queries Neptune *does* complete run at essentially the **same latency regardless of size**
(e.g. `date-day` ≈ 18 s at 32, 64, 128 *and* 256 GB; `distinct-count-low` ≈ 9.4 s everywhere).
Extra RAM converts OOM/timeout → completion (e.g. `group-by-complex-aggregate`: 32 GB timeout →
64 GB OOM → 128/256 GB pass), but doesn't make any individual query faster. Even at its best
(256 GB, 84/105), Neptune's geomean (7.6 s) is **~460× Fluree's** (16.6 ms).

### The 64 GB dip is real
64 GB passes *fewer* than 32 GB (10 vs 16), reproduced across two independent runs. On the
2xlarge, Neptune allocates more memory per query thread, so several heavy queries **OOM** at
64 GB where the more-constrained 32 GB merely runs them slowly — both fail, 64 GB fails a few
more. Net: Neptune is unstable on every sub-128 GB box.

---

## 3. Methodology & caveats

- **Hardware:** matched Graviton4 `r8g` (8 GB/vCPU) at 4 sizes. Fluree v4.1.0 (official
  installer, native) on an EC2 `r8g.*`; Neptune 1.4.7.0 on `db.r8g.*`, queried from an
  in-VPC client. Same `r8g` silicon throughout — only the size changes.
- **Harness:** this repo's `run_benchmark.sh` — 1 warmup + median of 3, **180 s** per-query
  `curl --max-time`, Accept TSV, **result cache off** on every engine.
- **Neptune query timeout:** Neptune's default `neptune_query_timeout` is **120 s** < the suite's
  180 s; we raised it to **180000** (custom cluster parameter group) so the budget matches every
  other engine. (An early run capped at 120 s is *not* used here.)
- **Warm state:** Neptune query benches ran post-load (warm). The one exception was the 32 GB
  tier, where the param-group change required a reboot that cold-wiped the cache; we re-ran it
  warm-settled. On a 32 GB box (~21 GB buffer pool < dataset) Neptune's pass-count is genuinely
  **noisy (9–48 range)** depending on cache state — reported here as 16/105 with that caveat.
- **256 GB load:** the cluster was resized in-place (no reload); its bench ran cold post-resize
  but, with a 256 GB buffer pool, showed no cold-cascade (84/105, in line with 128 GB).
- **Blank nodes:** Neptune's bulk loader rejects N-Triples blank nodes (confirmed 1:1: every
  blank-node line → one parse error). DBLP-core is ~42 % blank-node triples, so the data was
  **skolemized** for Neptune (as the [`dblp-core`](../dblp-core/REPORT.md) Blazegraph run also
  required). Fluree loaded the raw file. This is a Neptune capability gap, disclosed.
- **Not bit-comparable** to the same-box `dblp-core` run (different hardware family, engine
  versions, and — for Neptune — skolemized input).

---

## 4. Files

Per tier under `{32,64,128,256}gb/{fluree,neptune}/`:
- `*_load.json` — load time, throughput, triple count
- `*.tsv` — raw per-run timings (`query_id, description, run, status, time_ms, result_size, error`)
- `*_summary.tsv` — per-query median/min/max

Canonical query runs used in the tables above: Fluree — `fluree_summary.tsv` (32 GB uses the
clean re-run `fluree-final`); Neptune — `neptune_summary.tsv` (32 GB `neptune-clean`, 64 GB
`neptune-rerun`). Other TSVs in each folder are alternate/raw passes kept for the record.
</content>
