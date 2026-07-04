# BSBM benchmark — 1M

> **Run 2026-07-04, Fluree v4.1.2 (`25d8c28f4`) on the AWS m7a.4xlarge box (16c / 64 GB).**
> Real BSBM: bsbmtools-0.2 `testdriver` randomized query mix → **QMpH** (higher = faster).
> All three use cases × {1,4,8,16,32} clients. **0 timeouts.**

**Dataset:** BSBM 1M, pc=2785, `-fc` → **724,101 triples** · **Engine:** Fluree v4.1.2 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

## 1. Explore (12 read queries) — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 55,071 |
| 4 | 179,711 |
| 8 | 276,128 |
| 16 | 324,043 |
| 32 | 324,862 |

## 2. Business Intelligence — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 3,082 |
| 4 | 10,197 |
| 8 | 17,116 |
| 16 | 25,178 |
| 32 | 27,093 |

## 3. Explore-and-Update (5 writes + 25 reads / mix) — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 7,078 |
| 4 | 8,107 |
| 8 | 7,927 |
| 16 | 8,230 |
| 32 | 8,167 |


**Update** runs on a fresh pristine ledger per client-count at 2 MB reindex; it scales with concurrency to ~8,200 QMpH (the filtered-DELETE staging fix). Explore/BI carry the warm-on-write read cache.
