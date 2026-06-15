# BSBM — Berlin SPARQL Benchmark

The [Berlin SPARQL Benchmark](http://wbsg.informatik.uni-mannheim.de/bizer/berlinsparqlbenchmark/)
(Bizer & Schultz) over an **e-commerce** dataset — products, vendors, offers,
reviews, reviewers — at multiple scales, driven by BSBM's own test driver.

## How BSBM differs from `../sparqloscope/`

SPARQLoscope measures **per-query latency** (median-of-3 of fixed `.sparql` files,
caches cleared). BSBM measures **throughput**: its Java `testdriver` runs a
*randomized query mix* — each query template re-instantiated with fresh random
parameters every iteration, optionally across many concurrent clients — and
reports **QMpH** (query mixes per hour) and **QpS**. The parameter randomization
is deliberate: it defeats result caches, so engines are compared on real work.

Consequences for this repo:

- BSBM brings its **own measurement tooling** (`bsbmtools-0.2/`), not
  `common/run_benchmark.sh`. The driver *is* the harness.
- The data is **generated deterministically**, not downloaded — same
  `(toolkit version, -pc, flags)` → byte-identical N-Triples. The pin is the
  toolkit SHA + scale, and we record the generated dataset's SHA-256.
- Reports are **QMpH-shaped** (per use case / client count), produced by
  `parse_bsbm_xml.py` from the driver's `benchmark_result.xml` — not the
  SPARQLoscope `×best` latency grid.

We still keep the repo's directory conventions (`datasets/<scale>/`,
`reports/<scale>/meta.json` + `REPORT.md`).

## Layout

```
setup-bsbmtools.sh       fetch + verify the pinned BSBM toolkit (generator + driver)
run-scale-matrix.sh      explore + BI ramp at one larger scale (100m | 200m)
run-matrix.sh            sweep the test driver over {use case × clients × cache} cells
parse_bsbm_xml.py        benchmark_result.xml -> querymix_summary.tsv + per_query.tsv
bsbmtools-0.2/           the toolkit (gitignored; created by setup-bsbmtools.sh)
datasets/<scale>/        DATASET.md + fetch-data.sh (runs the generator at that -pc)
  bsbm-1m/   pc=2785      ~0.72 M triples  (smoke / harness validation)
  bsbm-100m/ pc=284826    ~100 M triples   (headline)
  bsbm-200m/ pc=570000    ~200 M triples   (stress)
reports/<scale>/         meta.json + runs/*.xml + REPORT.md + per_query.tsv
reports/v406-summary.tsv aggregate QMpH grid
```

## Results — Fluree v4.0.6 (2026-06-12)

Full matrix on the AWS m7a.4xlarge box (16c / 64 GB).
QMpH (query mixes/hour, higher = faster). Per-scale detail in
[`reports/<scale>/REPORT.md`](reports/); aggregate grid in
[`reports/v406-summary.tsv`](reports/v406-summary.tsv).

> **Engine comparison (Fluree vs Virtuoso 7 vs QLever)** — co-measured on the same
> box/driver: [`reports/engine-comparison/REPORT.md`](reports/engine-comparison/REPORT.md).
> Headline: Fluree leads Explore lookups 3–15× and is the most robust on heavy BI (0
> timeouts). Fluree and Virtuoso both cover all four use cases (Virtuoso is a mature
> read-write all-rounder but needs tuning); QLever can't do updates or the full Explore
> mix and is slowest on small queries, though strong on large BI analytics. Engine setup
> scripts in [`engines/`](engines/).

**Explore — single-client and peak QMpH:**

| scale | c1 | peak (c16/c32) |
|---|--:|--:|
| 1M   | 38,540 | 298,676 |
| 100M | 7,585  | 108,726 |
| 200M | 3,730  | 59,901  |

0 timeouts everywhere. BI completes every cell with 0 timeouts; its absolute QMpH at
scale is held down by a generator artifact (the `-fc` root-type `ProductType1` draw),
not the engine — see the 100M report. One operational caveat: BI@200M single-client can
OOM a 64 GB box on a root-type query (memory headroom, not a regression) — see the 200M
report.

## Engine target

Fluree first. Its HTTP server is SPARQL-1.1-Protocol-compatible enough to drive
directly — no adapter:

- **Query:**  `…/v1/fluree/query/<ledger>` (ledger-scoped returns
  `application/sparql-results+xml`, which the driver parses).
- **Update:** `…/v1/fluree/update/<ledger>` accepts form-encoded `update=…`
  (driver flag `-uqp update`) for the explore-and-update use case.

Other engines (Virtuoso, QLever — read-only, so no update use case) drop in later
by pointing `run-matrix.sh` at their endpoints.

## The matrix

Built up **1M first** (validate end-to-end), then tiered to 100M (headline) and
200M (stress).

- **Use cases:** `explore` (12 read queries), `bi` (business intelligence — 8
  analytic GROUP BY/aggregate queries), `update` (explore-and-update — interleaved
  SPARQL Update).
- **Concurrency (axis for throughput):** `-mt` clients 1 / 4 / 8 / 16 / 32.
- **Cache (axis for single-client latency):** Fluree leans on the **OS page cache**
  rather than a large app result cache, and BSBM's per-query parameter
  randomization neutralizes result caches anyway — so cold is competitive, not a
  handicap. Three states: **fully cold** (server restart + `drop_caches`),
  **page-warm / app-cold** (Fluree's sweet spot), **fully warm**.

Cache state is a single-client axis; server query-concurrency is a multi-client
axis — kept on different halves of the matrix so it doesn't explode.

## Run it (per scale)

```bash
cd benchmarks/bsbm

# 1. Toolkit + data (deterministic generator; no download).
./datasets/bsbm-1m/fetch-data.sh          # -> datasets/bsbm-1m/td/{dataset.nt,dataset_update.nt,*.dat}

# 2. Load into Fluree (run dir needs `fluree init` once), then start the server.
fluree create bsbm --from datasets/bsbm-1m/td/dataset.nt   # .nt imported natively
ulimit -n 1048576 && fluree server start  # endpoint :8090

# 3. Sweep matrix cells (writes benchmark_result XMLs).
#    Smoke: one explore cell, few runs.
./run-matrix.sh -t datasets/bsbm-1m/td -c explore -m 1 -r 25 -w 10 -k warm \
    -o reports/bsbm-1m/runs/smoke
#    1M latency block (cold):   -c explore,bi,update -m 1 -k cold
#    1M throughput ramp (warm): -c explore -m 4,8,16,32 -k warm

# 4. Build the report inputs from the XMLs.
python3 parse_bsbm_xml.py reports/bsbm-1m/runs/*.xml
```

## Provenance

- BSBM: <http://wbsg.informatik.uni-mannheim.de/bizer/berlinsparqlbenchmark/>
- Toolkit: bsbmtools v0.2 (Freie Universität Berlin), pinned in `setup-bsbmtools.sh`
  (SourceForge `bsbmtools-v0.2.zip`, sha256 `40f5e59b…`). Ships a prebuilt
  `lib/bsbm.jar` that runs on a modern JRE — no rebuild (its `build.xml` targets
  `-source 6`, which JDK 9+ rejects).
