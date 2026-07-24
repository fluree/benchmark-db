# BSBM benchmark — 100M

> **Fluree v4.1.2 (`13a78d2a`), run 2026-07-09** on the AWS m7a.4xlarge box (16c / 64 GB).
> Real BSBM: bsbmtools-0.2 `testdriver` randomized query mix → **QMpH** (higher = faster).
> Explore + BI (update omitted at scale) × {1,4,8,16,32} clients. **0 timeouts.**

**Dataset:** BSBM 100M, pc=284826, `-fc` → **100,000,748 triples** · **Engine:** Fluree v4.1.2 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

## 1. Explore (12 read queries) — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 12,812 |
| 4 | 55,299 |
| 8 | 99,823 |
| 16 | 142,807 |
| 32 | 149,272 |

## 2. Business Intelligence — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 32 |
| 4 | 78 |
| 8 | 104 |
| 16 | 103 |
| 32 | 105 |

_vs the `25d8c28f4` baseline: Explore **+17–28%**, BI **+8–18%** across clients._
