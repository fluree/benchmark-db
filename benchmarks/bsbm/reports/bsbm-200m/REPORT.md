# BSBM benchmark — 200M

> **Run 2026-07-04, Fluree v4.1.2 (`25d8c28f4`) on the AWS m7a.4xlarge box (16c / 64 GB).**
> Real BSBM: bsbmtools-0.2 `testdriver` randomized query mix → **QMpH** (higher = faster).
> Explore + BI (update omitted at scale) × {1,4,8,16,32} clients. **0 timeouts.**

**Dataset:** BSBM 200M, pc=570000, `-fc` → **200,031,975 triples** · **Engine:** Fluree v4.1.2 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

## 1. Explore (12 read queries) — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 6,334 |
| 4 | 25,676 |
| 8 | 43,114 |
| 16 | 63,295 |
| 32 | 67,264 |

## 2. Business Intelligence — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 17 |
| 4 | 40 |
| 8 | 40 |
| 16 | 39 |
| 32 | 38 |

