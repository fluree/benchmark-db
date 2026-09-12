# WGPB benchmark — Fluree v4.2.1 on Wikidata

**Fluree v4.2.1 completed all 850 queries with a 20.165 ms geometric mean** on
September 12, 2026. The retained Wikidata all-dump database contains
**21,127,103,263 distinct triples** from 21,512,007,172 input records. Queries ran
on one AWS `r7a.8xlarge` (32 vCPU / 256 GiB RAM), with one warmup and three measured
requests per query. There were no errors or timeouts.

This is a Fluree-only measurement. The workload contains 17 graph-pattern families
with 50 predicate instantiations each: joins, paths, squares, stars and triangles.
Every query uses `SELECT * ... LIMIT 1000`. The exact
[850 queries](../../queries/) and their archived checksums define the workload.

## 1. Query results

All aggregates below use the 850 per-query medians. No failure penalty is needed.

| Metric | Fluree v4.2.1 |
|---|---:|
| Completed | **850 / 850** |
| Measured HTTP requests | 2,550 |
| Errors / timeouts | 0 / 0 |
| Geometric mean | **20.165 ms** |
| Median | **16.443 ms** |
| Arithmetic mean | 90.899 ms |
| Under 100 ms | 672 / 850 (79.1%) |
| Under 500 ms | 815 / 850 (95.9%) |
| Under 1 s | 843 / 850 (99.2%) |
| Slowest query | 3,559.720 ms (`P4-03`) |

[All measured samples](engines/fluree.tsv) ·
[All per-query medians, minima and maxima](engines/fluree_summary.tsv) ·
[Machine-readable metadata](meta.json)

### By family

Each family contains 50 queries. All latency columns are in **milliseconds**;
maximum means the largest per-query median within the family.

| Family | Shape | Geo mean | Median | Mean | Maximum | Under 1 s |
|---|---|---:|---:|---:|---:|---:|
| J3 | object-object join, 3 patterns | 39.423 | 50.514 | 77.558 | 664.981 | 50/50 |
| J4 | object-object join, 4 patterns | 51.713 | 77.612 | 103.187 | 738.356 | 50/50 |
| P2 | path, length 2 | 10.624 | 9.069 | 24.371 | 165.699 | 50/50 |
| P3 | path, length 3 | 12.387 | 10.784 | 35.215 | 347.208 | 50/50 |
| P4 | path, length 4 | 26.451 | 22.066 | 245.996 | 3559.720 | 46/50 |
| S1 | directed 4-cycle (square) | 17.339 | 16.622 | 80.118 | 476.473 | 50/50 |
| S2 | bipartite square | 84.495 | 90.368 | 237.442 | 1585.606 | 49/50 |
| S3 | mixed-direction 4-cycle | 50.845 | 38.044 | 198.447 | 1578.148 | 49/50 |
| S4 | converging square | 42.685 | 28.088 | 175.337 | 1006.288 | 49/50 |
| T2 | subject out-star, 2 patterns | 5.043 | 4.413 | 9.032 | 121.028 | 50/50 |
| T3 | subject out-star, 3 patterns | 3.739 | 3.825 | 6.964 | 79.054 | 50/50 |
| T4 | subject out-star, 4 patterns | 5.024 | 4.239 | 9.105 | 60.834 | 50/50 |
| TI2 | object in-star, 2 patterns | 13.568 | 12.158 | 22.035 | 129.404 | 50/50 |
| TI3 | object in-star, 3 patterns | 19.513 | 21.474 | 42.645 | 435.475 | 50/50 |
| TI4 | object in-star, 4 patterns | 30.820 | 22.832 | 72.966 | 543.301 | 50/50 |
| Tr1 | triangle | 27.220 | 23.666 | 95.500 | 508.126 | 50/50 |
| Tr2 | triangle (variant) | 31.735 | 29.290 | 109.357 | 674.244 | 50/50 |

### Slowest 10 queries

| Query | Median (ms) |
|---|---:|
| `P4-03` | 3,559.720 |
| `P4-23` | 2,065.122 |
| `S2-38` | 1,585.606 |
| `S3-05` | 1,578.148 |
| `P4-35` | 1,415.023 |
| `P4-02` | 1,215.936 |
| `S4-12` | 1,006.288 |
| `S2-49` | 983.631 |
| `S3-26` | 979.650 |
| `P4-05` | 929.188 |

## 2. Dataset and retained store

| Field | Value |
|---|---|
| Dataset | Full Wikidata RDF all-dump, snapshot dated June 4, 2026 |
| Compressed source | 250,036,308,745 bytes |
| Input records | 21,512,007,172 |
| Distinct triples, verified by COUNT and index count | **21,127,103,263** |
| Duplicate input records | 384,903,909 |
| Import input | 5,379 verified gzip shards |
| Retained ledger size after import | 842,218,632,692 bytes (784.4 GiB) |

The [import reconciliation](evidence/import-reconciliation.json) accounts for every
input record: distinct triples plus duplicate records equals the input total.
The source is pinned at `s3://fluree-benchmark-data/wikidata-all/all-2026-06-04.nt.gz`;
the shard archive location and SHA-256 are recorded in [meta.json](meta.json).

This query run reused the database imported on September 8 without reimporting or
rechunking. The ledger size is an import-time measurement, not a measurement of
query memory use. Import time and peak import memory are not measured for v4.2.1
in this run.

## 3. Hardware, build and timing protocol

| Field | Value |
|---|---|
| Instance | AWS `r7a.8xlarge` |
| CPU | 32 vCPU, AMD EPYC 9R14, one thread per core |
| RAM | 256 GiB |
| Disk | 3,000 GB gp3, 16,000 IOPS / 1,000 MiB/s |
| OS | Ubuntu 24.04 |
| Engine | **Fluree v4.2.1**, source build `5529b53ea41f349b18b8ff0980a4b738de51b497` |
| Build | Rust 1.97.0, locked release profile, default features plus mimalloc, mold linker |
| Server | `fluree server run --listen-addr 127.0.0.1:8090 --log-level warn` |
| Cache | `FLUREE_CACHE_MAX_MB=88311`, calculated as 35% of detected RAM |
| Transport | Local HTTP SPARQL POST, `Accept: text/tab-separated-values` |
| Repetitions | One warmup, then three measured requests per query |
| Timeout | 120 seconds per request |

The [build provenance](evidence/build.json) preserves the captured build identity.
The measured executable's SHA-256 is
`d7eaa5ea2b45fa9feb1dd26c528dea45f901e567c988ceebdda1d5ec512ab820`.
Compilation completed on a separate host before measurement.

The runner executes queries sequentially in filename order. Latency is curl's
`time_total`, including HTTP response transfer and TSV serialization. Each query's
reported time is the median of its three measured requests. `result_size` in the
TSVs is **response bytes**, not rows.

A one-row startup query loaded the ledger before timing; a separate TI3-40 JSON
probe also preceded the suite. Caches were not cleared between requests or queries.
The full ledger exceeds RAM, but that alone does not establish whether a given
query's working set was cached. These are measurements from one full-suite pass,
not cold-cache timings or a concurrent throughput test.

J4-38 places `LIMIT 1000` after the closing `WHERE` brace. This syntax correction
preserves all predicates and triple patterns. Archived query hashes match the
published query files.

## 4. Completion and answer checks

Every query returned HTTP 200 for all three measured requests. All 2,550 measured
TSV response bodies are retained in the [verified archive](evidence/artifacts.tar.gz).
HTTP completion alone is not an independent correctness proof for all 850 queries.

For TI3-40, a separate JSON probe returned **1,000 distinct solutions**. All three
source triples of every solution were checked through subject-bound lookups,
avoiding the object-bound join path exercised by the query. Every check passed;
the [validation summary](evidence/ti3-validation.json), diagnostic queries and
responses are retained. This checks the returned solutions; `LIMIT 1000` does not
establish the total number of matching solutions. TI3-40's full-suite median is
**32.055 ms**.

## 5. Reproduction and evidence

See the [WGPB README](../../README.md#running) for the query command, cache setting
and retained-store requirements. Use the source commit and binary hash above to
identify the measured build. Results apply to this retained store and configuration.

The [evidence guide](evidence/README.md) describes the archive contents and checks.
To verify the publication locally from the repository root:

```bash
python3 benchmarks/wgpb/reports/wikidata-all/verify_results.py
```

To regenerate the per-query summary from the raw samples:

```bash
python3 common/summarize.py benchmarks/wgpb/reports/wikidata-all/engines/fluree.tsv
```
