# BSBM — Berlin SPARQL Benchmark

**Fluree v4.2.6 completed every BSBM cell — Explore, the SELECT-only Explore subset,
Business Intelligence and Explore-and-Update at 1M, 100M and 200M triples — with zero
timeouts and zero driver errors.** At 100M triples, single-client Explore ran at
**25,502 QMpH** and peaked at **383,019 QMpH (2,660 queries/s)** with 64 clients, on one
AWS `m7a.4xlarge` (16 vCPU / 64 GiB) with fsync enabled. Measured November 12, 2026;
every figure is the median of three repeats.

[Summary grid](reports/v4.2.6/summary.tsv) ·
[Per-query latencies](reports/v4.2.6/per_query.tsv) ·
[Raw driver XML](reports/v4.2.6/runs/) ·
[Capacity protocol](capacity/README.md)

The [Berlin SPARQL Benchmark](http://wbsg.informatik.uni-mannheim.de/bizer/berlinsparqlbenchmark/)
(Bizer & Schultz) runs an **e-commerce** workload — products, vendors, offers,
reviews, reviewers — driven by BSBM's own Java test driver. Unlike
[SPARQLoscope](../sparqloscope/), which times fixed queries, BSBM measures
**throughput**: each client repeatedly runs a query mix whose templates are
re-instantiated with random parameters, and the driver reports **QMpH** (query
mixes per hour). QpS = QMpH × operations per mix / 3600.

## Compared with QLever and Virtuoso

**Fluree v4.2.6 had the highest validated throughput in every multi-client comparison
below.** On the SELECT-only Explore subset, Fluree's peak was **10.5×** Virtuoso 7.2.17's and
**80×** QLever 0.6.0's at 1M triples, and **2.2×** and **9.7×** at 100M. Single-client
results are closer: at 100M Fluree was 6% ahead of Virtuoso on the SELECT subset, and at
200M **Virtuoso was 13% faster** on the SELECT subset and 8% faster on the full Explore mix.
**QLever was 64% faster** on single-client BI at 200M.

All three engines ran the same pinned driver, datasets, seed, timeout and query mixes on the
same host types: an `m7a.4xlarge` database and a separate `m7a.2xlarge` driver per scale,
every cell the median of three repeats. Fluree was measured November 12, 2026; QLever and
Virtuoso were measured in September 2026 and were not re-run.

![BSBM Explore SELECT subset throughput vs clients at 1M, 100M and 200M triples for Fluree v4.2.6, QLever 0.6.0 and Virtuoso 7.2.17; higher is faster](../../assets/bsbm-select-scaling.svg)

![BSBM full Explore mix throughput vs clients at 1M, 100M and 200M triples for Fluree v4.2.6 and Virtuoso 7.2.17; higher is faster](../../assets/bsbm-explore-virtuoso-scaling.svg)

![BSBM Business Intelligence throughput vs clients at 1M triples for Fluree v4.2.6 and QLever 0.6.0; higher is faster](../../assets/bsbm-bi-1m-scaling.svg)

![BSBM Explore-and-Update throughput vs clients at 1M triples for Fluree v4.2.6 and Virtuoso 7.2.17; higher is faster](../../assets/bsbm-update-1m-scaling.svg)

Filled points passed every check: three repeats finished, per-query result counts were
identical across repeats, and the spread was 5% or less. Hollow points on dashed segments
have a median but failed a check; ✕ marks a cell where a repeat errored, so there is no
median. Every cell and its status are in [`comparison.tsv`](reports/v4.2.6/comparison.tsv).

QMpH; **bold = fastest in the row**; the client count of each peak is in parentheses.

**Explore SELECT subset**

| scale | cell | Fluree v4.2.6 | QLever 0.6.0 | Virtuoso 7.2.17 |
|---|---|--:|--:|--:|
| 1M | 1 client | **230,611** | 3,337 | 50,083 |
| 1M | peak | **4,670,258** (64) | 58,328 (32) | 443,024 (16) |
| 100M | 1 client | **25,714** | 2,831 | 24,161 |
| 100M | peak | **388,768** (32) | 40,022 (128) | 175,510 (64) |
| 200M | 1 client | 16,185 | 2,637 | **18,309** |
| 200M | peak | **239,414** (32) | 33,642 (128) | no validated cell above 1 client |

**Full Explore mix** (Virtuoso only; validated Virtuoso cells)

| scale | clients | Fluree v4.2.6 | Virtuoso 7.2.17 |
|---|--:|--:|--:|
| 1M | 1 | **207,320** | 45,245 |
| 1M | 8 | **1,488,547** | 314,279 |
| 100M | 1 | **25,502** | 16,724 |
| 100M | 8 | **187,181** | 49,395 |
| 200M | 1 | 16,200 | **17,515** |
| 200M | 8 | **122,068** | 34,659 |

**Business Intelligence**

| scale | clients | Fluree v4.2.6 | QLever 0.6.0 | Virtuoso 7.2.17 |
|---|--:|--:|--:|--:|
| 1M | 1 | **5,963** | 775 | incorrect results |
| 1M | 32 | **74,040** | 26,098 | incorrect results |
| 100M | 1 | **50.4** | 41.0 | failed |
| 200M | 1 | 20.6 | **33.8** | failed |

**Explore-and-Update, 1M** (every write fsynced before acknowledgement)

| cell | Fluree v4.2.6 | Virtuoso 7.2.17 |
|---|--:|--:|
| 1 client | **36,916** | 13,940 |
| peak | **78,925** (32) | 25,405 (8) |

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
- **Fluree.** Three 1M Update cells (4, 8 and 16 clients) spread 5.1–8.0% across repeats
  and are drawn hollow; the 1-client and peak (32-client) cells passed every check.
- **Client counts.** QLever's 100M and 200M SELECT sweeps include 128 clients because its
  64-client throughput beat 32 clients by more than 5%; Fluree's and Virtuoso's did not.
- **Reproduce.** Engine setup is pinned in [`engines/README.md`](engines/README.md).
  `python3 reports/v4.2.6/collect_comparison.py` rebuilds `comparison.tsv` from the run
  archives (QLever and Virtuoso rows are carried over when the archives are absent); `python3 reports/v4.2.6/make_comparison_charts.py` redraws the charts.

## Results — Fluree v4.2.6

### Explore — QMpH

The 25-query Explore mix (11 active templates) of product lookups, reviews and offers.

| clients | 1M | 100M | 200M |
|--:|--:|--:|--:|
| 1 | 207,320 | 25,502 | 16,200 |
| 4 | 826,689 | 100,437 | 63,593 |
| 8 | 1,488,547 | 187,181 | 122,068 |
| 16 | 2,394,378 | 318,583 | 210,778 |
| 32 | 4,163,063 | 381,125 | **239,868** |
| 64 | **4,246,551** | **383,019** | 237,191 |

Throughput scales to 32 clients and plateaus there: c64 is within 2.0% of c32 at
every scale, so the protocol's optional 128-client point was not run. Peak
queries/s: 29,490 (1M), 2,660 (100M), 1,666 (200M).

### Explore SELECT subset — QMpH

The Explore mix without its two RDF-returning templates (Q9 `DESCRIBE`, Q12 `CONSTRUCT`):
20 SELECT queries per mix. It is the common read mix for engines that cannot return the
RDF/XML the full Explore mix requires.

| clients | 1M | 100M | 200M |
|--:|--:|--:|--:|
| 1 | 230,611 | 25,714 | 16,185 |
| 4 | 914,397 | 101,879 | 64,195 |
| 8 | 1,676,129 | 192,543 | 122,199 |
| 16 | 2,698,208 | 335,600 | 212,434 |
| 32 | 4,659,803 | **388,768** | **239,414** |
| 64 | **4,670,258** | 382,692 | 237,885 |

c64 is within 1.6% of c32 at every scale; no 128-client point was needed. Peak
queries/s: 25,946 (1M), 2,160 (100M), 1,330 (200M).

### Business Intelligence — QMpH

The 15-query BI mix (8 analytic GROUP BY / aggregate templates). At 100M and 200M
several BI queries aggregate over most of the dataset, so absolute QMpH is low.

| clients | 1M | 100M | 200M |
|--:|--:|--:|--:|
| 1 | 5,963 | 50.4 | 20.6 |
| 4 | 22,287 | 140.3 | 65.6 |
| 8 | 41,475 | 266.6 | 126.5 |
| 16 | 70,782 | 450.7 | 224.0 |
| 32 | **74,040** | **620.7** | **311.7** |

At 200M, 32 clients run up to seven simultaneous copies of the heaviest BI query
(Q8 over `ProductType1`). Server RSS in that 32-client cell peaked at 26.3 GiB on the
64 GiB server.

### Explore-and-Update

The 30-operation mix interleaves Explore reads with five SPARQL Updates. Mixed
operations/s counts every read and write in the mix; it is **not write TPS**.
Every write is fsynced before acknowledgement. Each figure is the median of three
complete runs, each starting from a fresh copy of the imported store.

| scale | clients | QMpH | mixed ops/s | range (ops/s) |
|---|--:|--:|--:|--:|
| 1M | 1 | 36,916 | 307.63 | 298.81–309.64 |
| 1M | 4 | 63,067 | 525.56 | 507.75–536.13 |
| 1M | 8 | 74,877 | 623.97 | 603.66–635.43 |
| 1M | 16 | 78,134 | 651.12 | 650.96–702.74 |
| 1M | 32 | **78,925** | **657.71** | 645.29–661.67 |
| 1M | 64 | 72,959 | 607.99 | 602.86–623.41 |
| 100M | 1 | 8,585 | 71.54 | 68.08–74.34 |
| 200M | 1 | 4,706 | 39.21 | 38.83–42.25 |

At 100M and 200M, Update ran **three full runs at one client** — 400 measured mixes
(12,000 operations) per run — with no multi-client sweep at those scales:

| scale | run 1 | run 2 | run 3 | median | measured seconds per run |
|---|--:|--:|--:|--:|--:|
| 100M | 68.08 | 71.54 | 74.34 | **71.54** | 176 / 168 / 161 |
| 200M | 42.25 | 39.21 | 38.83 | **39.21** | 284 / 306 / 309 |

Mixed ops/s. These runs vary more than the read cells (coefficient of variation
4.4% at 100M, 4.7% at 200M). Peak server RSS was 32.7–33.7 GiB at 100M and
36.7–37.8 GiB at 200M.

### 100M single-client per-query latency

Median of the three repeats' average query execution times (ms). All scales,
workloads and client counts are in [`per_query.tsv`](reports/v4.2.6/per_query.tsv).

| Explore query | Q1 | Q2 | Q3 | Q4 | Q5 | Q7 | Q8 | Q9 | Q10 | Q11 | Q12 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| ms | 4.53 | 1.53 | 6.70 | 8.37 | 21.01 | 9.81 | 3.59 | 0.41 | 9.91 | 0.49 | 0.74 |

| BI query | Q1 | Q2 | Q3 | Q4 | Q5 | Q6 | Q7 | Q8 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| ms | 3,255 | 93 | 3,232 | 1,788 | 13,553 | 602 | 1,968 | 16,030 |

## Validation

- **Completeness.** Every repeat of every cell finished with zero timeouts
  (300-second per-query cap) and no driver errors.
- **Repeatability.** Across three repeats, max − min is within 3.0% of the median for
  every Explore cell, 3.5% for the SELECT subset and 2.4% for BI. Update varies more:
  1M Update spread 2.5–8.0% (above 5% at 4, 8 and 16 clients) and the 100M and 200M
  runs spread 8.7%. Every Explore, SELECT and BI cell returned identical per-query
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
  clients and differ by 10–40 triples (one to four offers) at 32 and 64 clients.
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
  clients. Cells ran 159–226 seconds.
- **BI.** Two warmup mixes, then a fixed count of at least 2 × clients mixes, three
  repeats at 1/4/8/16/32 clients. Cells ran 138–744 seconds.
- **Mix counts.** The fixed per-cell mix counts are in the `measured_mixes` column of
  [`summary.tsv`](reports/v4.2.6/summary.tsv); they were calibrated with the pilot
  formulas in the capacity protocol.
- **Update.** Two mutating warmup mixes plus 400 measured mixes, three repeats. Each
  repeat restores an untouched store and runs a read preparation (1,000 warmup +
  100 measured SELECT mixes) first. Clients: 1/4/8/16/32/64 at 1M; 1 at 100M and 200M.
  The 100M/200M stores hold out 1,000 insert payloads (99,891,833 and 199,922,567
  starting triples).

### Build and environment

| | |
|---|---|
| Release | **Fluree v4.2.6**, official release binary (`x86_64-unknown-linux-gnu`) |
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
reports/v4.2.6/          summary.tsv, per_query.tsv, runs/<scale>/<workload>__c<N>__r<R>.xml
                         comparison.tsv (+ collect_comparison.py, make_comparison_charts.py)
reports/engine-comparison/  June 2026 cross-engine comparison (older releases)
```

## Provenance

- BSBM: <http://wbsg.informatik.uni-mannheim.de/bizer/berlinsparqlbenchmark/>
- Toolkit: bsbmtools v0.2 (Freie Universität Berlin), pinned in `setup-bsbmtools.sh`
  (SourceForge `bsbmtools-v0.2.zip`, sha256 `40f5e59b…`). Ships a prebuilt
  `lib/bsbm.jar` that runs on a modern JRE — no rebuild (its `build.xml` targets
  `-source 6`, which JDK 9+ rejects).
