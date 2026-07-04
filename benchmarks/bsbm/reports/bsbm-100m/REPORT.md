# BSBM benchmark — 100M

> **Run 2026-07-04, Fluree v4.1.2 (`25d8c28f4`) on the AWS m7a.4xlarge box (16c / 64 GB).**
> Real BSBM: bsbmtools-0.2 `testdriver` randomized query mix → **QMpH** (higher = faster).
> Explore + BI (update omitted at scale) × {1,4,8,16,32} clients. **0 timeouts.**

**Dataset:** BSBM 100M, pc=284826, `-fc` → **100,000,748 triples** · **Engine:** Fluree v4.1.2 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

## 1. Explore (12 read queries) — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 10,625 |
| 4 | 44,927 |
| 8 | 77,895 |
| 16 | 115,671 |
| 32 | 127,842 |

## 2. Business Intelligence — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 30 |
| 4 | 68 |
| 8 | 88 |
| 16 | 88 |
| 32 | 90 |

