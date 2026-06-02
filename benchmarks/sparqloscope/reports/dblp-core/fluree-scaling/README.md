# Fluree resource-scaling bench — DBLP-core (v4.0.5)

A side bench: **v4.0.5** and the same DBLP-core dataset run across five machine
sizes, to (a) anchor the main 64 GB config to the official release result and
(b) see how low on RAM/CPU we can go. Same dataset, same methodology as the main
report (native, 105 SPARQLoscope queries, 1 warmup + median of 3, **180 s** timeout
with the per-query budget). DBLP-core 2026-06-01, 561,544,658 triples, 27 GB index.

- **Build:** **v4.0.5**. The **16c / 64 GB** row is the same official-release run used
  in the main report (§1); the smaller configs are the same v4.0.5 code from the
  pre-release branch `feature/subquery-unification` @ `93be2083` (a source build
  self-reports 4.0.4, the tagged release reports 4.0.5), each on its own same-spec box.
- **Boxes:** AWS, AMD EPYC Zen4 (no-SMT), gp3, Ubuntu 24.04, dblp-core pulled from S3.
  `m7a.4xlarge`=16c/64G, `c7a.4xlarge`=16c/32G, `m7a.2xlarge`=8c/32G, `c7a.2xlarge`=8c/16G,
  `m7a.xlarge`=4c/16G.

## Results

| config | import | peak RSS | auto budget / parallelism | sweep | arith mean | median | geo mean |
|---|---|---|---|---|---|---|---|
| 16c / 64 GB | 527 s | 21.4 GB | 37.75 GB / 9 | 105/105 | **981 ms** | 69 ms | 124 ms |
| 16c / 32 GB | 594 s | 12.9 GB | 18.8 GB / 4 | 105/105 | 1,043 ms | 69 ms | 123 ms |
| 8c / 32 GB | 587 s | 13.0 GB | 18.8 GB / 4 | 105/105 | 1,028 ms | 68 ms | 132 ms |
| 8c / 16 GB | 972 s | 12.8 GB | 9.4 GB / 2 | 105/105 | 1,044 ms | 69 ms | 132 ms |
| 4c / 16 GB | 987 s | 12.9 GB | 9.4 GB / 2 | 105/105 | 1,062 ms | 87 ms | 144 ms |

(Per-config raw TSVs: `fluree-<ram>-<cores>.tsv` in this dir.)

## Findings

1. **v4.0.5 release at the main config (64 GB) = the §1 report number.** Box D:
   **105/105**, arith 981 ms, median 69 ms, geo 124 ms — within box-CPU variance of the
   pre-release branch (931 ms) and the original-box run (936 ms / 67 ms); same
   561,544,658 triples. Import 527 s / 21.4 GB peak is disk-bound and box-variant
   (release boxes ranged 458–527 s; the pre-release branch box drew 492 s / 20.4 GB) —
   not a release-driven change.

2. **Every config completes the full benchmark — 105/105 — down to 4 cores / 16 GB.**
   Halving the RAM (64→16 GB) and quartering the cores (16→4) does **not** drop any
   query in a single clean pass.

3. **Import is memory-budget-bound, not CPU-bound.** The importer auto-caps
   parallelism to fit its memory budget (~60 % of RAM): 9 threads @ 64 GB, 4 @ 32 GB,
   2 @ 16 GB. So 8c/32 ≈ 16c/32 (587 s vs 594 s, parallelism 4) and 4c/16 ≈ 8c/16
   (987 s vs 972 s, parallelism 2) — **dropping cores 16→8→4 changed nothing** at a
   fixed RAM because parallelism was already capped by the memory budget. (Consistent
   with the earlier finding that forcing `--parallelism 16` gave no gain.)

4. **Peak RSS tracks the budget**, and import stays well within the box: ~21 GB @
   64 GB, ~13 GB @ 32 GB, ~12.8 GB @ 16 GB (tight — ~2–3 GB headroom on a 16 GB box).
   16 GB import is ~2× slower (972–987 s, parallelism 2) but completes cleanly (no OOM).

5. **Queries: cores barely matter; RAM matters at the heavy tail.** 8c vs 16c @ 32 GB:
   1,028 vs 1,043 ms (noise). 16c→4c @ ~constant RAM: arith creeps ~981→~1,060 ms — the
   light queries pay a little for fewer cores (median 69→87 ms at 4c), while the heavy
   scan queries pay for less page cache at lower RAM. **Median stays well under 90 ms
   everywhere.**

**Bottom line:** Fluree v4.0.5 runs the entire DBLP-core SPARQLoscope benchmark clean
in one pass on as little as **16 GB / 4 cores**, only ~8 % slower on the heaviest
queries than 64 GB / 16 cores.
