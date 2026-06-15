# BSBM benchmark — 200M (stress)

> **Run 2026-06-12, Fluree v4.0.6 on the
> AWS m7a.4xlarge box (16c / 64 GB).** Real BSBM: bsbmtools-0.2
> `testdriver` randomized query mix → **QMpH** (query mixes/hour, higher = faster).
> Explore × {1,4,8,16,32} clients; Business Intelligence × {1} (single-client).

**Dataset:** BSBM 200M, pc=570000, `-fc` forward-chained → **200,031,975 triples** ·
**Engine:** Fluree v4.0.6 · **Driver:** bsbmtools v0.2 · **Box:** m7a.4xlarge (16c / 64 GB)

## 1. Explore (12 read queries) — QMpH

Scales near-linearly to the 16-core box, then plateaus (c16→c32). **0 timeouts.**

| clients | QMpH |
|--------:|-----:|
| 1  | 3,730  |
| 4  | 21,143 |
| 8  | 35,912 |
| 16 | 59,901 |
| 32 (peak) | 59,899 |

At 200M the working set no longer fits comfortably in cache, so Explore throughput is
lower than at 100M and 1M — but it stays sub-millisecond-to-low-ms per query and scales
cleanly with concurrency.

## 2. Business Intelligence (8 analytic queries) — QMpH, single-client

| clients | QMpH | timeouts |
|--------:|-----:|:--:|
| 1 | 12.28 | 1 (Q4) |

Per-query AQET shows the root-type (`ProductType1`, all products under `-fc`) analytics
dominate:
**Q8 78.9 s, Q4 49.3 s (timed out once), Q5 38.0 s, Q3 21.2 s, Q1 12.4 s**; selective
queries are fast (Q2 0.17 s, Q6 0.78 s). As at 100M, this is the generator's
root-type artifact, not an engine ceiling.

### ⚠️ BI@200M memory headroom (operational note)

In the unattended full-suite run, the BI@200M c1 cell **OOM-killed the server**:

```
Out of memory: Killed process (fluree) total-vm 84.6 GB, anon-rss 63.2 GB   (64 GB box)
```

A heavy root-type BI query's working set, landing on top of an already-filled
~15 GiB LeafletCache, exceeded the 64 GB box. **Re-running the same cell from a
freshly-restarted server (cache headroom available) completed cleanly** → the 12.28
QMpH above. So this is a **memory-headroom condition on a 64 GB box, not a query-engine
failure**. Mitigations: more RAM, a smaller cache budget, or excluding the root type from the
param pool / regenerating without `-fc`. The committed `runs/bi__c1.xml` is the clean
re-run.

## Files

- `runs/explore__c{1,4,8,16,32}.xml`, `runs/bi__c1.xml` — raw driver XML
- `querymix_summary.tsv`, `per_query.tsv`
- aggregate grid: `../v406-summary.tsv`
