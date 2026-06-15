# Fluree resource-scaling bench — DBLP-core (Fluree v4.0.6)

A side bench: the **Fluree v4.0.6 build** and the same DBLP-core dataset run
across three machine sizes (halving series: 64 GB → 32 GB → 16 GB), to (a) anchor the
main 64 GB config to the §1 report result and (b) see how low on RAM/CPU we can go.
Same dataset, same methodology as the main report (native, 105 SPARQLoscope queries,
1 warmup + median of 3, **180 s** timeout). DBLP-core 2026-06-01, 561,544,658 triples,
27 GB index.

- **Build:** **Fluree v4.0.6** — the same binary as the main §1 report (geo 19.4 ms,
  105/105). The **16c / 64 GB** row copies the main-report result exactly. The two
  smaller configs are the same binary, each on its own same-spec box.
- **Boxes:** AWS, AMD EPYC Zen4 (no-SMT), 250 GB gp3, Ubuntu 24.04, dblp-core pulled
  from S3. `m7a.4xlarge`=16c/64G, `m7a.2xlarge`=8c/32G, `m7a.xlarge`=4c/16G.

## Results

| config | import | budget / parallelism | sweep | arith mean | median | geo mean |
|---|---|---|---|---|---|---|
| 16c / 64 GB | 512 s | 37.75 GB / 9 (auto) | 105/105 | **251 ms** | 41 ms | **19 ms** |
| 8c / 32 GB | 776 s | 25.1 GB / 6 (auto) | 105/105 | 265 ms | 44 ms | 20 ms |
| 4c / 16 GB | 952 s | 12.5 GB / 3 (auto) | 105/105 | 338 ms | 49 ms | 25 ms |

For reference, **QLever on the full 16c/64 GB box** (from the main report): arith 1,904 ms,
median 310 ms, geo 202 ms.

(Per-config raw TSVs in this dir, named `fluree-<RAM>gb-<cores>c.tsv` —
`fluree-64gb-16c.tsv`, `fluree-32gb-8c.tsv`, `fluree-16gb-4c.tsv`, plus `_summary` variants.)

## Findings

1. **v4.0.6 at the main config (16c/64 GB) = the §1 report number** —
   105/105, arith 251 ms, median 41 ms, geo 19 ms; 561,544,658 triples.

2. **105/105 clean down to 4c / 16 GB.** Halving the RAM (64→16 GB) and reducing cores
   (16→4) still passes the full benchmark. Serving the 27 GB index is light on RAM; every
   query completes inside 180 s even on the smallest config.

3. **Import is memory-budget-bound, not CPU-bound.** The auto budget sets parallelism:
   9 threads @ 64 GB, 6 @ 32 GB, 3 @ 16 GB. Import times scale with the budget (chunk
   count), not raw core count.

4. **Geo and median stay excellent as we scale down; arith mean creeps slightly.**
   Geo: 19 → 20 → 25 ms; median: 41 → 44 → 49 ms — essentially flat. Arith: 251 → 265 →
   338 ms, reflecting a handful of heavier queries paying for fewer cores and less page
   cache at 4c/16 GB.

**Bottom line:** Fluree v4.0.6 runs the entire DBLP-core SPARQLoscope
benchmark clean (105/105) down to **4c / 16 GB**, with a geo-mean of **25 ms** —
**8.1× faster than QLever's full 16c/64 GB box (202 ms)**.
