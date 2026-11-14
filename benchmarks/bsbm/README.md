# BSBM — Berlin SPARQL Benchmark

**Fluree v4.2.7 completed every BSBM cell — Explore, the SELECT-only Explore subset,
Business Intelligence and Explore-and-Update at 1M, 100M and 200M triples — with zero
timeouts and zero driver errors.** At 100M triples, single-client Explore ran at
**27,308 QMpH** and peaked at **435,619 QMpH (3,025 queries/s)** with 32 clients, on one
AWS `m7a.4xlarge` (16 vCPU / 64 GiB) with fsync enabled. Measured November 14, 2026;
every figure is the median of three repeats.

[Summary grid](reports/v4.2.7/summary.tsv) ·
[Per-query latencies](reports/v4.2.7/per_query.tsv) ·
[Raw driver XML](reports/v4.2.7/runs/) ·
[Capacity protocol](capacity/README.md)

The [Berlin SPARQL Benchmark](http://wbsg.informatik.uni-mannheim.de/bizer/berlinsparqlbenchmark/)
(Bizer & Schultz) runs an **e-commerce** workload — products, vendors, offers,
reviews, reviewers — driven by BSBM's own Java test driver. Unlike
[SPARQLoscope](../sparqloscope/), which times fixed queries, BSBM measures
**throughput**: each client repeatedly runs a query mix whose templates are
re-instantiated with random parameters, and the driver reports **QMpH** (query
mixes per hour). QpS = QMpH × operations per mix / 3600.

## Compared with QLever and Virtuoso

**Fluree v4.2.7 had the highest validated throughput in every multi-client comparison
below.** On the SELECT-only Explore subset, Fluree's peak was **10.6×** Virtuoso 7.2.17's and
**81×** QLever 0.6.0's at 1M triples, and **2.5×** and **11×** at 100M. Single-client
results are closer: at 100M Fluree was 14% ahead of Virtuoso on the SELECT subset, and at
200M **Virtuoso was 6% faster** on the SELECT subset and 2% faster on the full Explore mix.
**QLever was 60% faster** on single-client BI at 200M.

All three engines ran the same pinned driver, datasets, seed, timeout and query mixes on the
same host types: an `m7a.4xlarge` database and a separate `m7a.2xlarge` driver per scale,
every cell the median of three repeats. Fluree was measured November 14, 2026; QLever and
Virtuoso were measured in September 2026 and were not re-run.

![BSBM Explore SELECT subset throughput vs clients at 1M, 100M and 200M triples for Fluree v4.2.7, QLever 0.6.0 and Virtuoso 7.2.17; higher is faster](../../assets/bsbm-select-scaling.svg)

![BSBM full Explore mix throughput vs clients at 1M, 100M and 200M triples for Fluree v4.2.7 and Virtuoso 7.2.17; higher is faster](../../assets/bsbm-explore-virtuoso-scaling.svg)

![BSBM Business Intelligence throughput vs clients at 1M triples for Fluree v4.2.7 and QLever 0.6.0; higher is faster](../../assets/bsbm-bi-1m-scaling.svg)

![BSBM Explore-and-Update throughput vs clients at 1M triples for Fluree v4.2.7 and Virtuoso 7.2.17; higher is faster](../../assets/bsbm-update-1m-scaling.svg)

Filled points passed every check: three repeats finished, per-query result counts were
identical across repeats, and the spread was 5% or less. Hollow points on dashed segments
have a median but failed a check; ✕ marks a cell where a repeat errored, so there is no
median. Every cell and its status are in [`comparison.tsv`](reports/v4.2.7/comparison.tsv).

QMpH; **bold = fastest in the row**; the client count of each peak is in parentheses.

**Explore SELECT subset**

| scale | cell | Fluree v4.2.7 | QLever 0.6.0 | Virtuoso 7.2.17 |
|---|---|--:|--:|--:|
| 1M | 1 client | **234,922** | 3,337 | 50,083 |
| 1M | peak | **4,712,525** (64) | 58,328 (32) | 443,024 (16) |
| 100M | 1 client | **27,644** | 2,831 | 24,161 |
| 100M | peak | **443,090** (32) | 40,022 (128) | 175,510 (64) |
| 200M | 1 client | 17,350 | 2,637 | **18,309** |
| 200M | peak | **266,146** (32) | 33,642 (128) | no validated cell above 1 client |

**Full Explore mix** (Virtuoso only; validated Virtuoso cells)

| scale | clients | Fluree v4.2.7 | Virtuoso 7.2.17 |
|---|--:|--:|--:|
| 1M | 1 | **210,583** | 45,245 |
| 1M | 8 | **1,504,118** | 314,279 |
| 100M | 1 | **27,308** | 16,724 |
| 100M | 8 | **206,344** | 49,395 |
| 200M | 1 | 17,217 | **17,515** |
| 200M | 8 | **133,553** | 34,659 |

**Business Intelligence**

| scale | clients | Fluree v4.2.7 | QLever 0.6.0 | Virtuoso 7.2.17 |
|---|--:|--:|--:|--:|
| 1M | 1 | **6,178** | 775 | incorrect results |
| 1M | 32 | **76,238** | 26,098 | incorrect results |
| 100M | 1 | **53.7** | 41.0 | failed |
| 200M | 1 | 21.2 | **33.8** | failed |

**Explore-and-Update, 1M** (every write fsynced before acknowledgement)

| cell | Fluree v4.2.7 | Virtuoso 7.2.17 |
|---|--:|--:|
| 1 client | **37,742** | 13,940 |
| peak | **78,771** (32) | 25,405 (8) |

Coverage and caveats:

- **Virtuoso.** Most Explore and SELECT cells at 16+ clients, and at 200M from 4 clients,
  returned different per-query result counts across repeats or spread more than 5%; the
  1M SELECT and 100M full-Explore 64-client cells had an errored repeat. Its BI Q5 returns
  an empty result for every product type at 1M, so its BI throughput is not equivalent
  work ([details](reports/engine-comparison/BI-Q5-CORRECTNESS.md)); BI at 100M and 200M
  did not complete (Q4 timeouts).
- **QLever.** The full Explore mix needs RDF/XML `DESCRIBE`/`CONSTRUCT` responses that
  QLever 0.6.0 does not return to the driver, so it runs only the SELECT subset. BI at
  100M and 200M completed only at 1 client; the 4–32 client cells failed repeatedly.
  Update was not run: durable fsync-before-acknowledgement updates have not been
  established for QLever 0.6.0. Its SELECT 200M 4-client cell spread 10.7%.
- **Fluree.** The 1M 16-client Update cell spread 6.8% across repeats and is drawn hollow;
  its median, 84,063 QMpH, is higher than the 32-client peak shown above, which passed every
  check, as did every other 1M Update cell.
- **Client counts.** QLever's 100M and 200M SELECT sweeps include 128 clients because its
  64-client throughput beat 32 clients by more than 5%; Fluree's and Virtuoso's did not.
- **Reproduce.** Engine setup is pinned in [`engines/README.md`](engines/README.md).
  `python3 reports/v4.2.7/collect_comparison.py` rebuilds `comparison.tsv` from the run
  archives (QLever and Virtuoso rows are carried over when the archives are absent); `python3 reports/v4.2.7/make_comparison_charts.py` redraws the charts.

## Results — Fluree v4.2.7

### Explore — QMpH

The 25-query Explore mix (11 active templates) of product lookups, reviews and offers.

| clients | 1M | 100M | 200M |
|--:|--:|--:|--:|
| 1 | 210,583 | 27,308 | 17,217 |
| 4 | 834,636 | 109,362 | 68,950 |
| 8 | 1,504,118 | 206,344 | 133,553 |
| 16 | 2,428,805 | 361,558 | 232,012 |
| 32 | 4,200,836 | **435,619** | **266,144** |
| 64 | **4,294,671** | 433,334 | 264,231 |

Throughput scales to 32 clients and plateaus there: c64 is within 2.2% of c32 at
every scale, so the protocol's optional 128-client point was not run. Peak
queries/s: 29,824 (1M), 3,025 (100M), 1,848 (200M).

### Explore SELECT subset — QMpH

The Explore mix without its two RDF-returning templates (Q9 `DESCRIBE`, Q12 `CONSTRUCT`):
20 SELECT queries per mix. It is the common read mix for engines that cannot return the
RDF/XML the full Explore mix requires.

| clients | 1M | 100M | 200M |
|--:|--:|--:|--:|
| 1 | 234,922 | 27,644 | 17,350 |
| 4 | 933,650 | 111,775 | 69,745 |
| 8 | 1,710,769 | 211,920 | 134,493 |
| 16 | 2,740,269 | 373,626 | 236,726 |
| 32 | 4,662,265 | **443,090** | **266,146** |
| 64 | **4,712,525** | 439,750 | 263,215 |

c64 is within 1.1% of c32 at every scale; no 128-client point was needed. Peak
queries/s: 26,181 (1M), 2,462 (100M), 1,479 (200M).

### Business Intelligence — QMpH

The 15-query BI mix (8 analytic GROUP BY / aggregate templates). At 100M and 200M
several BI queries aggregate over most of the dataset, so absolute QMpH is low.

| clients | 1M | 100M | 200M |
|--:|--:|--:|--:|
| 1 | 6,178 | 53.7 | 21.2 |
| 4 | 23,024 | 147.4 | 66.2 |
| 8 | 42,870 | 285.5 | 126.2 |
| 16 | 73,431 | 483.5 | 232.9 |
| 32 | **76,238** | **679.8** | **318.0** |

At 200M, 32 clients run up to seven simultaneous copies of the heaviest BI query
(Q8 over `ProductType1`). Server RSS in that 32-client cell peaked at 26.5 GiB on the
64 GiB server.

### Explore-and-Update

The 30-operation mix interleaves Explore reads with five SPARQL Updates. Mixed
operations/s counts every read and write in the mix; it is **not write TPS**.
Every write is fsynced before acknowledgement. Each figure is the median of three
complete runs, each starting from a fresh copy of the imported store.

| scale | clients | QMpH | mixed ops/s | range (ops/s) |
|---|--:|--:|--:|--:|
| 1M | 1 | 37,742 | 314.52 | 313.69–317.02 |
| 1M | 4 | 64,480 | 537.34 | 532.58–552.18 |
| 1M | 8 | 75,478 | 628.99 | 625.70–637.30 |
| 1M | 16 | **84,063** | **700.52** | 680.55–728.27 |
| 1M | 32 | 78,771 | 656.43 | 655.94–688.29 |
| 1M | 64 | 78,216 | 651.80 | 635.01–659.60 |
| 100M | 1 | 10,010 | 83.42 | 78.27–85.50 |
| 200M | 1 | 5,986 | 49.89 | 43.65–53.73 |

At 100M and 200M, Update ran **three full runs at one client** — 400 measured mixes
(12,000 operations) per run — with no multi-client sweep at those scales:

| scale | run 1 | run 2 | run 3 | median | measured seconds per run |
|---|--:|--:|--:|--:|--:|
| 100M | 85.50 | 78.27 | 83.42 | **83.42** | 140 / 153 / 144 |
| 200M | 49.89 | 53.73 | 43.65 | **49.89** | 241 / 223 / 275 |

Mixed ops/s. These runs vary more than the read cells (coefficient of variation
4.5% at 100M, 10.4% at 200M). Peak server RSS was 31.9–33.5 GiB at 100M and
36.7–38.0 GiB at 200M.

### 100M single-client per-query latency

Median of the three repeats' average query execution times (ms). All scales,
workloads and client counts are in [`per_query.tsv`](reports/v4.2.7/per_query.tsv).

| Explore query | Q1 | Q2 | Q3 | Q4 | Q5 | Q7 | Q8 | Q9 | Q10 | Q11 | Q12 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| ms | 4.48 | 1.46 | 6.27 | 7.79 | 17.99 | 9.53 | 3.47 | 0.35 | 9.80 | 0.43 | 0.67 |

| BI query | Q1 | Q2 | Q3 | Q4 | Q5 | Q6 | Q7 | Q8 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| ms | 2,833 | 87 | 2,892 | 1,722 | 12,689 | 599 | 1,917 | 15,008 |

## Validation

- **Completeness.** Every repeat of every cell finished with zero timeouts
  (300-second per-query cap) and no driver errors.
- **Repeatability.** Across three repeats, max − min is within 2.4% of the median for
  every Explore cell, 1.7% for the SELECT subset and 3.5% for BI. Update varies more:
  1M Update spread 1.1–6.8% (above 5% only at 16 clients), the 100M runs spread 8.7%
  and the 200M runs 20.2%. Every Explore, SELECT and BI cell returned identical per-query
  result-count summaries across its repeats.
- **BI Q7 row counts.** Q7 ranks products by offer count and keeps the top 1,000,
  with no tie-breaker, so correct executions can select different tied products and
  return different row counts. Row counts were identical across the three repeats of
  every BI cell here. Q7 responses from this release were not separately validated
  against an independently rebuilt answer set.
- **Update persistence.** After each Update run, the triple count was identical
  before and after a graceful restart (100M: 99,967,221; 200M: 199,998,114). These
  are graceful-restart checks, not power-loss tests.
- **Update triple counts.** The final counts equal the starting count plus the triples
  of the 800 measured insert payloads minus 10 triples for each effective offer delete.
  At 200M the count is exact with all 1,200 deletes effective (199,922,567 + 87,547 −
  12,000); at 100M one delete matched nothing (99,891,833 + 87,378 − 11,990). The insert
  payloads contain no duplicate triples and none already in the dataset. BSBM draws a
  delete's offer from a range that includes offers in payloads not yet inserted, and
  such a delete matches nothing. At 1M that is about 12% of deletes and depends on
  how clients interleave, so 1M final counts are identical across repeats up to 16
  clients and differ by 10–20 triples (one or two offers) at 32 and 64 clients.
- **Update result counts.** Per-query average result counts differed between some
  Update repeats (1M at 4+ clients; 100M at one client).

## Method

Protocol details are in [`capacity/README.md`](capacity/README.md). In summary:

- **Hosts.** Database: AWS `m7a.4xlarge` (16 vCPU AMD EPYC, 64 GiB), 500 GB gp3
  (6,000 IOPS / 500 MiB/s), Ubuntu 24.04. The driver runs on a **separate**
  `m7a.2xlarge` in the same availability zone, one database/generator pair per scale.
  Only one measured workload runs per pair at a time, and each read cell starts a fresh
  server process followed by a triple-count check.
- **Driver.** bsbmtools v0.2 with a transport-only HTTP keep-alive patch
  (`capacity/prepare-driver.py`; query semantics unchanged), JDK 21, 24 GiB heap,
  seed 808080, 300-second query timeout.
- **Explore and SELECT subset.** A single-client qualification cell (1,000 warmup /
  100 measured mixes), then per client count 1,000 warmup mixes and a fixed mix count
  calibrated to about 180 seconds (minimum 120 s), three repeats at 1/4/8/16/32/64
  clients. Cells ran 156–209 seconds.
- **BI.** Two warmup mixes, then a fixed count of at least 2 × clients mixes, three
  repeats at 1/4/8/16/32 clients. Cells ran 134–742 seconds.
- **Mix counts.** The fixed per-cell mix counts are in the `measured_mixes` column of
  [`summary.tsv`](reports/v4.2.7/summary.tsv); they were calibrated with the pilot
  formulas in the capacity protocol.
- **Update.** Two mutating warmup mixes plus 400 measured mixes, three repeats. Each
  repeat restores an untouched store and runs a read preparation (1,000 warmup +
  100 measured SELECT mixes) first. Clients: 1/4/8/16/32/64 at 1M; 1 at 100M and 200M.
  The 100M/200M stores hold out 1,000 insert payloads (99,891,833 and 199,922,567
  starting triples).

### Build and environment

| | |
|---|---|
| Release | **Fluree v4.2.7**, release build (`x86_64-unknown-linux-gnu`) |
| Server | `fluree server run --listen-addr 0.0.0.0:8182 --log-level warn` |
| Environment | `FLUREE_STORAGE_FSYNC=1`, `FLUREE_INDEXING_ENABLED=true`, `FLUREE_REINDEX_MIN_BYTES=2097152` (import and serving) |

### Datasets

Generated deterministically by bsbmtools v0.2 with forward chaining (`-fc`), N-Triples:

| scale | `-pc` | triples | SHA256 |
|---|--:|--:|---|
| 1M | 2,785 | 724,101 | `0eca9f19829be6390700196c5de4fe6e3d0610e1cd09d7f780de6526a95a48c8` |
| 100M | 284,826 | 100,000,748 | `9f72d493f1a8040558afdeb5b719dae9037625bb4911b36387a44746097707ba` |
| 200M | 570,000 | 200,031,975 | `6ded674926fe39153d557f2a059526723901edcea7232a8924bd7b49881936f8` |

### Other engines

QLever 0.6.0 and Virtuoso 7.2.17 results under this protocol are in
[Compared with QLever and Virtuoso](#compared-with-qlever-and-virtuoso); their pinned
setup is in [`engines/README.md`](engines/README.md). The June 2026
[engine comparison](reports/engine-comparison/REPORT.md) used older releases and an
earlier short-run protocol; it is kept for history and documents Virtuoso's incorrect
BI Q5 results.

## Run it

On the database host, from the repository root:

```bash
bash benchmarks/bsbm/setup-bsbmtools.sh
# 1M: bash benchmarks/bsbm/datasets/bsbm-1m/fetch-data.sh (writes datasets/bsbm-1m/td/).
# 100M shown; use -pc 570000 for 200M.
TD="$PWD/benchmarks/bsbm/datasets/bsbm-100m/td" && mkdir -p "$TD"
(cd benchmarks/bsbm/bsbmtools-0.2 && ./generate -fc -pc 284826 -s nt -dir "$TD" -fn "$TD/dataset")
python3 benchmarks/bsbm/engines/check-dataset.py 100m "$TD/dataset.nt" --output dataset-100m.json

export FLUREE_STORAGE_FSYNC=1 FLUREE_INDEXING_ENABLED=true FLUREE_REINDEX_MIN_BYTES=2097152
fluree init && fluree create bsbm --from "$TD/dataset.nt"
ulimit -n 1048576 && fluree server run --listen-addr 0.0.0.0:8182 --log-level warn
```

On the separate generator (same dataset and `td/` directory), build the keep-alive
driver once, then run cells:

```bash
python3 benchmarks/bsbm/capacity/prepare-driver.py
export BSBM_DATA="$PWD/benchmarks/bsbm/datasets/bsbm-100m/td" DB=http://DB_PRIVATE_IP:8182

python3 benchmarks/bsbm/capacity/run-cell.py --engine fluree --data "$BSBM_DATA" \
  --endpoint "$DB/v1/fluree/query/bsbm:main" \
  --workload explore --clients 32 --warmups 1000 --runs 19400 \
  --output results/fluree-100m-explore-c32-r1

python3 benchmarks/bsbm/capacity/run-cell.py --engine fluree --data "$BSBM_DATA" \
  --endpoint "$DB/v1/fluree/query/bsbm:main" \
  --update-endpoint "$DB/v1/fluree/update/bsbm:main" \
  --workload update --clients 1 --warmups 2 --runs 400 --minimum-seconds 0 \
  --output results/fluree-100m-update-c1-r1
```

`--runs 19400` is the calibrated 100M c32 count; use `--workload select` for the SELECT
subset. Calibrate other cells with the pilot formulas in the
[capacity protocol](capacity/README.md), which also covers BI, store snapshots for
Update and telemetry. The ledger-scoped query endpoint returns
`application/sparql-results+xml`, and the update endpoint accepts form-encoded
`update=…`; the driver talks to Fluree directly, with no adapter.

## Layout

```
setup-bsbmtools.sh       fetch + verify the pinned BSBM toolkit (generator + driver)
datasets/<scale>/        DATASET.md + fetch-data.sh (deterministic generator)
capacity/                sustained-throughput protocol, keep-alive driver, run-cell.py
engines/                 pinned Virtuoso / QLever setup for cross-engine runs
parse_bsbm_xml.py        benchmark_result.xml -> querymix_summary.tsv + per_query.tsv
run-*matrix.sh           earlier short-run sweeps (superseded by capacity/)
reports/v4.2.7/          summary.tsv, per_query.tsv, runs/<scale>/<workload>__c<N>__r<R>.xml
                         comparison.tsv (+ collect_comparison.py, make_comparison_charts.py)
reports/engine-comparison/  June 2026 cross-engine comparison (older releases)
```

## Provenance

- BSBM: <http://wbsg.informatik.uni-mannheim.de/bizer/berlinsparqlbenchmark/>
- Toolkit: bsbmtools v0.2 (Freie Universität Berlin), pinned in `setup-bsbmtools.sh`
  (SourceForge `bsbmtools-v0.2.zip`, sha256 `40f5e59b…`). Ships a prebuilt
  `lib/bsbm.jar` that runs on a modern JRE — no rebuild (its `build.xml` targets
  `-source 6`, which JDK 9+ rejects).
