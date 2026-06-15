# benchmark-db

Reproducible RDF / SPARQL benchmarks for [Fluree](https://labs.flur.ee), run head-to-head
against other engines on **identical data and hardware**. Every benchmark is
self-contained under [`benchmarks/`](benchmarks/); they share one query runner and one
report generator under [`common/`](common/). All engines run **natively** (no Docker,
matching the SPARQLoscope paper's recommendation), with each engine's result cache
disabled or cleared per query so every run actually re-executes.

The current suite is **[SPARQLoscope](https://github.com/ad-freiburg/sparqloscope)** —
105 SPARQL 1.1 queries probing joins, aggregates, property paths, filters, string
functions, and large result sets — run at two dataset scales (561 M → 8.19 B triples),
plus the **[Wikidata Graph Pattern Benchmark](benchmarks/wgpb/)** (WGPB, 850 basic
graph pattern queries) on the full 21.5 B-triple Wikidata all-dump.

---

## Headline — DBLP-core: 7 engines, one box

The full SPARQLoscope suite over **DBLP-core** (~561 M triples) with
**all seven engines on the same machine** (AWS `m7a.4xlarge`, 16 c / 64 GB) so the
comparison is purely engine-vs-engine. **Fluree leads every aggregate** and is one of
only two engines (with QLever) to answer all 105 queries.

![DBLP-core geometric-mean query time, all 7 engines on one box](assets/dblp-core-geomean.svg)

| metric (lower = faster) | **Fluree** | QLever | Virtuoso | MillenniumDB | Jena | Oxigraph | Blazegraph |
|---|---|---|---|---|---|---|---|
| **queries passed** | **105/105** | 105/105 | 103/105 | 103/105 | 34/105 | 39/105 | 3/105 |
| **geo mean (P=2)** | **19.4 ms (1.0×)** | 202 ms (10.4×) | 300 ms (15.4×) | 1,664 ms (86×) | 67.7 s (3487×) | 87.0 s (4486×) | 333 s (17158×) |
| **geo mean (P=10)** | **19.4 ms (1.0×)** | 202 ms (10.4×) | 309 ms (15.9×) | 1,716 ms (88×) | 200.9 s (10355×) | 239.4 s (12338×) | 1,590 s (81934×) |
| **median (passed only)** | **41 ms (1.0×)** | 310 ms (7.6×) | 326 ms (7.9×) | 3,894 ms (95×) | 6,033 ms (147×) | 5,090 ms (124×) | 23.0 s (562×) |

_The geo means follow the [SPARQLoscope paper](https://ad-publications.cs.uni-freiburg.de/ISWC_sparqloscope_BKTU_2025.pdf)'s
official aggregate: a failed or timed-out query counts as 2× (P=2) or 10× (P=10) the
180 s timeout, so every engine is scored on the same 105 queries._

→ **[Full DBLP-core report](benchmarks/sparqloscope/reports/dblp-core/REPORT.md)** ·
[per-engine raw TSVs](benchmarks/sparqloscope/reports/dblp-core/engines/) ·
[run metadata & setup facts](benchmarks/sparqloscope/reports/dblp-core/meta.json)

> Fluree is **v4.0.6** (native source build). The other six engines were
> measured on the same box; the small box-to-box variance does not change the ranking —
> see the report caveats.

---

## Fluree scales down 4× — performance virtually unchanged

We then re-ran Fluree alone (same **v4.0.6** build) on progressively smaller boxes,
and the headline is how little the numbers move: **geo mean 19 → 20 → 25 ms and median
41 → 44 → 49 ms from the full 16 c / 64 GB box down to one-quarter the cores and RAM
(4 c / 16 GB), with all 105 queries passing at every size.** And that ¼-box result is
still **8.1× faster on geo mean** than the next fastest engine (QLever) running on the
full box — 5.6× arith, 6.3× median.

![Fluree scaling ramp vs QLever's full-box result](assets/dblp-core-scaling.svg)

| Fluree config | cores | RAM | passed | arith | median | geo |
|---|---|---|---|---|---|---|
| 16c / 64 GB (full) | 16 | 64 GB | 105/105 | 251 ms | 41 ms | 19 ms |
| 8c / 32 GB (½ box) | 8 | 32 GB | 105/105 | 265 ms | 44 ms | 20 ms |
| **4c / 16 GB (¼ box)** | **4** | **16 GB** | **105/105** | **338 ms** | **49 ms** | **25 ms** |
| _QLever, full 16c/64 GB (for reference)_ | 16 | 64 GB | 105/105 | _1,904 ms_ | _310 ms_ | _202 ms_ |

→ **[Resource-scaling bench](benchmarks/sparqloscope/reports/dblp-core/fluree-scaling/)**
(per-config raw TSVs + findings)

---

## All runs at a glance

Fluree leads every aggregate at both scales. On the SPARQLoscope penalized geo mean
(P=2), the v4.0.6 build is **10.4× faster than the next fastest engine (QLever) on
DBLP-core (561 M) and 10.5× on Wikidata-Truthy (8.19 B)**.

| benchmark | triples | engines | box | Fluree passed | Fluree geo P=2 (vs next fastest) | report |
|---|---|---|---|---|---|---|
| **DBLP-core** | 561 M | 7 | `m7a.4xlarge` 16c/64 GB | **105/105** | **19.4 ms** (QLever 10.4×) | [report](benchmarks/sparqloscope/reports/dblp-core/REPORT.md) |
| **Wikidata-truthy** | 8.19 B | 5 | `r7a.16xlarge` 64c/512 GB | **105/105** | **363 ms** (QLever 10.5×) | [report](benchmarks/sparqloscope/reports/wikidata-truthy/REPORT.md) |
| **WGPB** (Wikidata all-dump) | 21.5 B | 1 (Fluree only) | `r7a.8xlarge` 32c/256 GB | **850/850** | **43 ms** | [report](benchmarks/wgpb/reports/wikidata-all/REPORT.md) |

_Wikidata-truthy is the hardest SPARQLoscope scale (8.19 B triples); passed-counts fall
for every other engine there — Fluree is the only engine to answer all 105 queries, at
both scales. The WGPB row is the separate 850-query graph-pattern benchmark on the full
21.5 B-triple Wikidata all-dump (794 GB index, ~3× RAM): 100% completion, 0 timeouts._

At the 8.19 B scale the same ordering holds — Fluree fastest on geo mean, QLever next:

![Wikidata-truthy geometric-mean query time, 5 engines on one box](assets/wikidata-truthy-geomean.svg)

---

## Reproduce it

Datasets are pinned and published to **`s3://fluree-benchmark-data/`**
(`dblp-core/`, `wikidata-truthy/`, `wikidata-all/`) so you don't have to re-derive them;
the per-dataset notes under [`benchmarks/sparqloscope/datasets/`](benchmarks/sparqloscope/datasets/)
record exact sources, versions, and checksums.

```bash
# 1. install Fluree (official v4.0.6 release — native binary, no source build).

curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/fluree/db/releases/latest/download/fluree-db-cli-installer.sh | sh

# 2. load a dataset, start the server, then run the suite
common/run_benchmark.sh --endpoint http://localhost:8090/v1/fluree/query/dblp:main \
  -r 3 -w 1 -t 180 -o benchmarks/sparqloscope/reports/dblp-core/engines/fluree.tsv

# 3. (re)generate a report and the headline charts
python3 common/generate_report.py benchmarks/sparqloscope/reports/dblp-core/
python3 common/make_charts.py
```

- **Native setup for every engine:** [`common/engine-setup/`](common/engine-setup/)
  ([Fluree](common/engine-setup/fluree.md) ·
  [QLever](common/engine-setup/qlever.md) ·
  [Virtuoso](common/engine-setup/virtuoso.md) ·
  [MillenniumDB](common/engine-setup/millenniumdb.md) ·
  [Jena](common/engine-setup/jena.md) ·
  [Oxigraph](common/engine-setup/oxigraph.md) ·
  [Blazegraph](common/engine-setup/blazegraph.md))
- **Query runner:** [`common/run_benchmark.sh`](common/run_benchmark.sh) —
  warmup + median-of-N, per-query timeout/budget, body or form POST.
- **Report + chart generators:** [`common/generate_report.py`](common/generate_report.py),
  [`common/summarize.py`](common/summarize.py), [`common/make_charts.py`](common/make_charts.py).

## Methodology notes

- **Native, not Docker** — containerization distorts results (per the SPARQLoscope paper).
- **No warm result cache** — each engine's result cache is disabled or cleared per query,
  so every timed run re-executes (stricter than the paper's warm-cache protocol).
- **1 warmup + median of 3 runs**, per-query timeout (180 s for DBLP-core, 300 s for the
  billion-scale SPARQLoscope runs, 120 s for WGPB).
- **Engine-vs-engine on one box per dataset** — absolute times are box-specific and not
  bit-comparable to the published SPARQLoscope table (different dumps/dates). See each
  report's caveats for the precise dataset version, deviations, and per-engine notes.

## Repo layout

```
benchmarks/
  sparqloscope/
    queries/            105 SPARQL 1.1 query files
    datasets/           per-dataset source/version/checksum notes
    reports/
      dblp-core/        7-engine same-box run (REPORT.md, meta.json, engines/*.tsv,
                        fluree-scaling/)
      wikidata-truthy/  8.19 B-triple 5-engine run (Blazegraph excluded)
  wgpb/
    queries/            850 WGPB basic-graph-pattern queries (17 shapes x 50)
    reports/
      wikidata-all/     21.5 B-triple full all-dump run (Fluree)
common/
  run_benchmark.sh      generic SPARQL benchmark runner
  generate_report.py    meta.json + engines/*.tsv -> REPORT.md
  summarize.py          raw TSV -> per-query summary
  make_charts.py        headline SVG charts (this README)
  engine-setup/         native install/load/serve notes per engine
assets/                 generated charts
```
