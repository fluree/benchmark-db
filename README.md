# benchmark-db

Reproducible RDF / SPARQL benchmarks for [Fluree](https://flur.ee), run alongside
other engines (QLever today) on identical data and hardware. A suite — each
benchmark is self-contained under `benchmarks/`, and they share one runner and one
report generator under `common/`.

## Headline results

**SPARQLoscope** (105 SPARQL 1.1 queries) over **DBLP-KG** (~1.57 B triples),
**Fluree v4.0.5 vs QLever**, same box (AWS r7a.4xlarge, 16c / 128 GB), result cache
cleared per query, median of 3 runs.

| metric (lower = faster) | Fluree | QLever |
|---|---|---|
| arith mean | **5.6 s** (1.0×) | 21.4 s (3.8×) |
| geo mean | **227 ms** (1.0×) | 364 ms (1.6×) |
| median | **93 ms** (1.0×) | 368 ms (4.0×) |
| queries fastest | **71 / 105** | 34 / 105 |
| import time | **1,047 s** | 3,937 s |

Fluree leads 10 of 13 query categories (incl. OPTIONAL, MINUS, EXISTS, UNION, GROUP
BY, transitive paths); QLever leads dataset-statistics, FILTER, and result-export.
Results agree across both engines except a small set of **documented
engine-semantics differences** (blank-node `FILTER`, `DAY()`/`MONTH()` on a `gYear`,
string collation) — Fluree follows the SPARQL spec where they diverge; five
queries (regex-prefix + transitive-path, ±1 row) are still under review.

→ **[Full report — per-query numbers & methodology](benchmarks/sparqloscope/reports/dblp-kg/REPORT.md)**
 · [How to reproduce](#quickstart-any-benchmark)

> **Preliminary.** This is the larger DBLP **KG+citations** dataset, not the paper's
> ~502 M **core** — comparable *between these two engines on this box*, not to the
> published SPARQLoscope table. See the report's caveats.

## Benchmarks

| benchmark | status | what it is |
|---|---|---|
| [`sparqloscope`](benchmarks/sparqloscope/) | active | 105 SPARQL 1.1 queries ([ad-freiburg/sparqloscope](https://github.com/ad-freiburg/sparqloscope)) over DBLP / Wikidata |
| `bsbm` | planned | Berlin SPARQL Benchmark |
| `lubm` | planned | Lehigh University Benchmark |

## Layout

```
common/                     shared, benchmark-agnostic tooling
  run_benchmark.sh          generic SPARQL runner (--endpoint / --queries / --clear-url)
  summarize.py              aggregate a run; --diff two runs
  generate_report.py        build a dataset REPORT.md from engine summaries + meta
  engine-setup/             generic per-engine setup notes (qlever, fluree)
benchmarks/<name>/          one self-contained benchmark
  queries/                  the query set
  report-categories.tsv     query -> category map (drives the report's rollup)
  datasets/<dataset>/       DATASET.md, fetch-data.sh, Qleverfile per dataset
  reports/<dataset>/        meta.json, engines/*.tsv, correctness.json, REPORT.md
```

## Quickstart (any benchmark)

```bash
cd benchmarks/sparqloscope
# 1. load a dataset into the engine under test (see datasets/<ds>/DATASET.md)
# 2. run the queries against its SPARQL endpoint:
../../common/run_benchmark.sh --endpoint http://localhost:8090/v1/fluree/query/dblp:main \
    --queries queries -o reports/<ds>/engines/fluree.tsv
# 3. regenerate the report:
python3 ../../common/generate_report.py reports/<ds>
```

See each benchmark's `README.md` for specifics, and `common/README.md` for the
runner + reporting details (the `abs (×best)` cell convention, category rollups,
correctness column, and how to add an engine or a benchmark).
