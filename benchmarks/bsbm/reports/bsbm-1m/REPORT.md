# BSBM benchmark — 1M

> **Explore + BI: Fluree v4.1.2 (`13a78d2a`); Update: Fluree v4.1.2 (`e563e9bb`).** Run 2026-07-09
> on the AWS m7a.4xlarge box (16c / 64 GB). (`e563e9bb` = `13a78d2a` + the fix that skips the
> per-update stats-view rebuild for single-pattern `DELETE WHERE`; it removes an earlier write
> regression and lands Update above the prior baseline — see §3.)
> Real BSBM: bsbmtools-0.2 `testdriver` randomized query mix → **QMpH** (higher = faster).
> All three use cases × {1,4,8,16,32} clients. **0 timeouts.**

**Dataset:** BSBM 1M, pc=2785, `-fc` → **724,101 triples** · **Engine:** Fluree v4.1.2 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

## 1. Explore (12 read queries) — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 62,800 |
| 4 | 199,700 |
| 8 | 298,154 |
| 16 | 324,028 |
| 32 | 323,184 |

## 2. Business Intelligence — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 4,349 |
| 4 | 14,522 |
| 8 | 23,569 |
| 16 | 35,916 |
| 32 | 37,727 |

## 3. Explore-and-Update (5 writes + 25 reads / mix) — QMpH

| clients | QMpH |
|--:|--:|
| 1 | 7,333 |
| 4 | 8,168 |
| 8 | 8,295 |
| 16 | 8,424 |
| 32 | 8,423 |


**Update** runs on a fresh pristine ledger per client-count at 2 MB reindex; it scales with concurrency to ~8,400 QMpH. `e563e9bb` skips a redundant per-update stats-view rebuild for single-pattern `DELETE WHERE` (the mix's DELETE) — recovering an earlier −3 to −7% write regression and landing Update **+0.8 to +4.6% above** the prior `25d8c28f4` baseline. Explore/BI carry the warm-on-write read cache — vs the `25d8c28f4` baseline, Explore is **+8–14%** at low/mid concurrency (flat at saturation) and **BI +38–43%** across the board.
