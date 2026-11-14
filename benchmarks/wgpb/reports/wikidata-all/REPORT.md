# WGPB benchmark — Fluree v4.2.7 on Wikidata

**Fluree v4.2.7 completed all 850 queries with a 14.364 ms geometric mean** on
November 14, 2026. The retained Wikidata all-dump database contains
**21,127,057,160 distinct triples** from 21,512,007,172 input records. Queries ran
on one AWS `r7a.8xlarge` (32 vCPU / 256 GiB RAM), with one warmup and three measured
requests per query. There were no errors or timeouts.

This is a Fluree-only measurement. The workload contains 17 graph-pattern families
with 50 predicate instantiations each: joins, paths, squares, stars and triangles.
Every query uses `SELECT * ... LIMIT 1000`. The exact
[850 queries](../../queries/) and their archived checksums define the workload.

## 1. Query results

All aggregates below use the 850 per-query medians. No failure penalty is needed.

| Metric | Fluree v4.2.7 |
|---|---:|
| Completed | **850 / 850** |
| Measured HTTP requests | 2,550 |
| Errors / timeouts | 0 / 0 |
| Geometric mean | **14.364 ms** |
| Median | **10.212 ms** |
| Arithmetic mean | 70.792 ms |
| Under 100 ms | 724 / 850 (85.2%) |
| Under 500 ms | 816 / 850 (96.0%) |
| Under 1 s | 844 / 850 (99.3%) |
| Slowest query | 1,849.628 ms (`S3-05`) |
| Peak server RSS | 154.2 GiB |

A second full pass on the same server, immediately after the first, gave a
15.12 ms geometric mean and the same slowest query; its samples are in the
[archive](evidence/artifacts.tar.gz). The figures above are the first pass.

[All measured samples](engines/fluree.tsv) ·
[All per-query medians, minima and maxima](engines/fluree_summary.tsv) ·
[Machine-readable metadata](meta.json)

### By family

Each family contains 50 queries. All latency columns are in **milliseconds**;
maximum means the largest per-query median within the family.

| Family | Shape | Geo mean | Median | Mean | Maximum | Under 1 s |
|---|---|---:|---:|---:|---:|---:|
| J3 | object-object join, 3 patterns | 12.440 | 10.095 | 24.471 | 221.642 | 50/50 |
| J4 | object-object join, 4 patterns | 18.322 | 15.321 | 40.348 | 235.008 | 50/50 |
| P2 | path, length 2 | 6.375 | 5.706 | 12.537 | 165.552 | 50/50 |
| P3 | path, length 3 | 8.255 | 8.692 | 13.266 | 64.238 | 50/50 |
| P4 | path, length 4 | 11.447 | 9.703 | 37.739 | 388.179 | 50/50 |
| S1 | directed 4-cycle (square) | 17.575 | 16.097 | 86.140 | 553.519 | 50/50 |
| S2 | bipartite square | 92.183 | 98.493 | 275.351 | 1848.792 | 47/50 |
| S3 | mixed-direction 4-cycle | 53.847 | 38.510 | 220.065 | 1849.628 | 48/50 |
| S4 | converging square | 45.521 | 35.129 | 193.837 | 1141.126 | 49/50 |
| T2 | subject out-star, 2 patterns | 4.685 | 4.292 | 8.480 | 116.903 | 50/50 |
| T3 | subject out-star, 3 patterns | 3.494 | 3.165 | 5.902 | 41.296 | 50/50 |
| T4 | subject out-star, 4 patterns | 4.618 | 3.996 | 7.520 | 65.720 | 50/50 |
| TI2 | object in-star, 2 patterns | 7.494 | 7.232 | 9.829 | 57.084 | 50/50 |
| TI3 | object in-star, 3 patterns | 10.408 | 10.530 | 15.662 | 81.930 | 50/50 |
| TI4 | object in-star, 4 patterns | 16.471 | 17.577 | 26.538 | 132.669 | 50/50 |
| Tr1 | triangle | 27.492 | 22.255 | 105.605 | 552.911 | 50/50 |
| Tr2 | triangle (variant) | 32.407 | 28.969 | 120.171 | 771.238 | 50/50 |

### Slowest 10 queries

| Query | Median (ms) |
|---|---:|
| `S3-05` | 1,849.628 |
| `S2-38` | 1,848.792 |
| `S2-49` | 1,479.216 |
| `S4-12` | 1,141.126 |
| `S3-26` | 1,116.085 |
| `S2-16` | 1,045.760 |
| `S4-26` | 963.556 |
| `S3-25` | 956.756 |
| `S2-29` | 903.092 |
| `S2-06` | 871.428 |

## 2. Dataset and retained store

| Field | Value |
|---|---|
| Dataset | Full Wikidata RDF all-dump, snapshot dated June 4, 2026 |
| Compressed source | 250,036,308,745 bytes |
| Input records | 21,512,007,172 |
| Distinct triples, verified by COUNT and index count | **21,127,057,160** |
| Duplicate input records | 384,950,012 |
| Import input | 5,379 verified gzip shards |
| Retained ledger size after import | 841,586,356,521 bytes (783.8 GiB) |

The [import reconciliation](evidence/import-reconciliation.json) accounts for every
input record: distinct triples plus duplicate records equals the input total.
The source is pinned at `s3://fluree-benchmark-data/wikidata-all/all-2026-06-04.nt.gz`;
the shard archive location and SHA-256 are recorded in [meta.json](meta.json).

This query run reused the database imported on November 12 from the same verified
shards, without reimporting or rechunking. That import took 21,580 seconds (about
6 hours) with a peak resident set of 234 GiB on this host. The ledger size is an
import-time measurement, not a measurement of query memory use.

## 3. Hardware, build and timing protocol

| Field | Value |
|---|---|
| Instance | AWS `r7a.8xlarge` |
| CPU | 32 vCPU, AMD EPYC 9R14, one thread per core |
| RAM | 256 GiB |
| Disk | 3,000 GB gp3, 16,000 IOPS / 1,000 MiB/s |
| OS | Ubuntu 24.04 |
| Engine | **Fluree v4.2.7** |
| Build | Rust 1.97.0, locked `dist` release profile (fat LTO), default features (includes mimalloc) |
| Server | `fluree server run --listen-addr 127.0.0.1:8090 --log-level warn` |
| Cache | `FLUREE_CACHE_MAX_MB=88311`, calculated as 35% of detected RAM |
| Transport | Local HTTP SPARQL POST, `Accept: text/tab-separated-values` |
| Repetitions | One warmup, then three measured requests per query |
| Timeout | 120 seconds per request |

The [build record](evidence/build.json) lists the toolchain, profile and features.

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

The first measured response of every query was compared with a reference response
captured earlier from the same retained store: all 850 were byte-for-byte identical
([comparison](evidence/answer-comparison.json)).

For TI3-40, a separate JSON probe returned **1,000 distinct solutions**. All three
source triples of every solution were checked through subject-bound lookups,
avoiding the object-bound join path exercised by the query. Every check passed;
the [validation summary](evidence/ti3-validation.json), diagnostic queries and
responses are retained. This checks the returned solutions; `LIMIT 1000` does not
establish the total number of matching solutions. TI3-40's full-suite median is
**31.326 ms**.

## 5. Reproduction and evidence

See the [WGPB README](../../README.md#running) for the query command, cache setting
and retained-store requirements. Results apply to this retained store and configuration.

The [evidence guide](evidence/README.md) describes the archive contents and checks.
To verify the publication locally from the repository root:

```bash
python3 benchmarks/wgpb/reports/wikidata-all/verify_results.py
```

To regenerate the per-query summary from the raw samples:

```bash
python3 common/summarize.py benchmarks/wgpb/reports/wikidata-all/engines/fluree.tsv
```
