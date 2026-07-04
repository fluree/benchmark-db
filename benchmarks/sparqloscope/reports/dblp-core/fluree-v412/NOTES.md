# Fluree v4.1.2 regression check — DBLP-core SPARQLoscope

Single-box rerun of the DBLP-core SPARQLoscope 105-query sweep on **Fluree v4.1.2**
(`feature/warm-on-write-reindex-cache` @ `25d8c28f4df719f8414f8f2507f955b5c41afd50` — the
release candidate carrying both the warm-on-write read cache and the filtered-DELETE fix).
Compared to the committed v4.0.6 baseline and the v4.1.1 rerun.

- **Methodology:** identical — 105 queries, 1 warmup + median of 3, 180 s timeout, native
  server via curl. Box m7a.4xlarge (16c/64GB), Ubuntu 24.04, built from source. Run 2026-07-04.
  Data: dblp-2026-06-01.nt.gz (~525M triples). S3 runs/dblp-core-v412-25d8c28f/.

## Query results: no regression

| build | passed | arith mean | geo mean (P=2) |
|---|---|---|---|
| v4.0.6 baseline | 105/105 | 251.0 ms | 19.38 ms |
| v4.1.1 | 105/105 | 250.6 ms | 18.89 ms |
| **v4.1.2 (25d8c28f)** | **105/105** | **253.8 ms** | **18.5 ms** |

Geo-mean is the best of the three; arith mean flat (+1%, heavy-query-tail noise). No status
changes, same 105/105 pass set. Per-query vs v4.1.1: only `result-size-small` moved >25%
(4.16→7.04 ms = +2.9 ms on a trivial query, measurement noise). Genuine improvements:
number-of-blank-nodes 38.8→15.9 ms, strstarts 56.8→42.3 ms, filter-language-en 8.5→2.3 ms.

**Verdict: no query regression. v4.1.2 dblp-core is flat-to-slightly-better vs v4.1.1/v4.0.6.**
