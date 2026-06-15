# SPARQLoscope

The **105 SPARQL 1.1 queries** from the [SPARQLoscope](https://github.com/ad-freiburg/sparqloscope)
project (Bast et al., ISWC 2025), run over DBLP and compared across engines. The
queries cover JOIN, OPTIONAL, MINUS, EXISTS, UNION, GROUP BY, DISTINCT, transitive
paths, REGEX/string, numeric and date functions, dataset statistics, and result-size export.

The query set is **per dataset family**: each dataset's queries are instantiated
against its own predicates, so DBLP and Wikidata are different concrete queries
(same 105 categories). DBLP's set lives at the top level (used by `dblp-core`);
Wikidata-Truthy has its own under its dataset dir.

```
queries/                 the 105 DBLP .sparql files (used by dblp-core)
query-set.tsv            DBLP query set (provenance; split_queries.py regenerates queries/)
report-categories.tsv    query -> category map (drives the report rollup; category ids are shared)
datasets/
  dblp-core/             DBLP bibliography only (our run: ~561.5M distinct triples)
  wikidata-truthy/       Wikidata Truthy (~8.19B); has its OWN query-set.tsv + queries/
                         (from SPARQLoscope's wikidata-truthy.benchmark.tsv — Wikidata predicates)
reports/<dataset>/       meta.json, engines/*.tsv, correctness.json, REPORT.md
```

## Run it (per dataset)

```bash
cd benchmarks/sparqloscope

# 1. Load the dataset into each engine (see datasets/<ds>/DATASET.md + Qleverfile).
#    Fluree:  fluree create dblp --from <data-dir>   (then: fluree server start)
#    QLever:  see ../../common/engine-setup/qlever.md

# 2. Run the 105 queries against each engine's SPARQL endpoint.
#    QUERIES is the dataset's query dir: DBLP -> "queries"; Wikidata -> "datasets/wikidata-truthy/queries".
../../common/run_benchmark.sh --queries "$QUERIES" \
    --endpoint "http://localhost:8090/v1/fluree/query/<ledger>:main" \
    -o reports/<ds>/engines/fluree_summary.tsv
# QLever (clear its result cache per query so it re-executes — see common/engine-setup/qlever.md):
../../common/run_benchmark.sh --queries "$QUERIES" \
    --endpoint "http://localhost:7015" \
    --clear-url "http://localhost:7015/?access-token=<token>&cmd=clear-cache" \
    -o reports/<ds>/engines/qlever_summary.tsv

# 3. Generate the comparison report:
python3 ../../common/generate_report.py reports/<ds>
```

## Notes

- **Dataset matters.** The published SPARQLoscope table uses the **core DBLP**
  bibliography (~502M, `dblp-core/`); our run uses the 2026-06-01 DROPS archive
  (~574M), comparable *between engines on this box* but not bit-for-bit to the
  published numbers. See each `datasets/<ds>/DATASET.md`.
- **Result correctness** is checked alongside timing (the report's `results`
  column). Engines can legitimately differ on edge cases (blank-node `FILTER`
  semantics, `DAY()` on a `gYear`, string collation) — documented per report.
- `query-set.tsv` is the upstream provenance; `split_queries.py` regenerates
  `queries/` from it (`split_queries.py <tsv> <out_dir>` for a non-default dataset,
  e.g. `split_queries.py datasets/wikidata-truthy/query-set.tsv datasets/wikidata-truthy/queries`).
- **Per-dataset queries.** The 105 categories are shared, but each dataset's
  concrete queries use its own predicates. Wikidata-Truthy's set
  (`datasets/wikidata-truthy/`) is SPARQLoscope's `wikidata-truthy.benchmark.tsv`
  — generated against the truthy dump, so result counts won't match the paper's
  2025-04-18 snapshot (we run the current one).
