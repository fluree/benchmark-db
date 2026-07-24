# BSBM benchmark — 200M

> **Fluree v4.1.2 (`13a78d2a`), run 2026-07-09** on the AWS m7a.4xlarge box (16c / 64 GB).
> Real BSBM: bsbmtools-0.2 `testdriver` randomized query mix → **QMpH** (higher = faster).
> Explore + BI (update omitted at scale) × {1,4,8,16,32} clients. **0 timeouts.**

**Dataset:** BSBM 200M, pc=570000, `-fc` → **200,031,975 triples** · **Engine:** Fluree v4.1.2 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

## 1. Explore (12 read queries) — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 7,044 |
| 4 | 32,677 |
| 8 | 53,914 |
| 16 | 82,716 |
| 32 | 85,559 |

## 2. Business Intelligence — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 18 |
| 4 | 42 |
| 8 | 40 |
| 16 | 40 |
| 32 | 40 |

_vs the `25d8c28f4` baseline: Explore **+11–31%**, BI flat-to-better (**+1–6%**), and 0 timeouts (baseline had 1 at BI c1)._
