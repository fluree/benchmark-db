# SPARQLoscope

The **105 SPARQL 1.1 queries** from the [SPARQLoscope](https://github.com/ad-freiburg/sparqloscope)
project (Bast et al., ISWC 2025), run over DBLP and compared across engines. The
queries cover JOIN, OPTIONAL, MINUS, EXISTS, UNION, GROUP BY, DISTINCT, transitive
paths, REGEX/string, numeric and date functions, dataset statistics, and result-size export.

```
queries/                 the 105 .sparql files
query-set.tsv            the SPARQLoscope-generated query set (provenance; split_queries.py regenerates queries/)
report-categories.tsv    query -> category map (drives the report rollup)
datasets/
  dblp-kg/               DBLP + OpenCitations citations (~1.57B) — what we've run
  dblp-core/             DBLP bibliography only (~502M) — matches the published table
  wikidata-truthy/       Wikidata Truthy (~8B) — needs a bigger box
reports/<dataset>/       meta.json, engines/*.tsv, correctness.json, REPORT.md
```

## Run it (per dataset)

```bash
cd benchmarks/sparqloscope

# 1. Load the dataset into each engine (see datasets/<ds>/DATASET.md + Qleverfile).
#    Fluree:  fluree create dblp --from <data-dir>   (then: fluree server start)
#    QLever:  see ../../common/engine-setup/qlever.md

# 2. Run the 105 queries against each engine's SPARQL endpoint:
../../common/run_benchmark.sh --queries queries \
    --endpoint "http://localhost:8090/v1/fluree/query/dblp:main" \
    -o reports/<ds>/engines/fluree_summary.tsv
# QLever (clear its result cache per query so it re-executes — see common/engine-setup/qlever.md):
../../common/run_benchmark.sh --queries queries \
    --endpoint "http://localhost:7015" \
    --clear-url "http://localhost:7015/?access-token=dblp_token&cmd=clear-cache" \
    -o reports/<ds>/engines/qlever_summary.tsv

# 3. Generate the comparison report:
python3 ../../common/generate_report.py reports/<ds>
```

## Notes

- **Dataset matters.** The published SPARQLoscope table uses the **core DBLP**
  bibliography (~502M, `dblp-core/`). The larger **KG+citations** tar (`dblp-kg/`,
  ~1.57B) is the same query set on more data — comparable *between engines on this
  box*, but not to the published numbers. See each `datasets/<ds>/DATASET.md`.
- **Result correctness** is checked alongside timing (the report's `results`
  column). Engines can legitimately differ on edge cases (blank-node `FILTER`
  semantics, `DAY()` on a `gYear`, string collation) — documented per report.
- `query-set.tsv` is the upstream provenance; `split_queries.py` regenerates
  `queries/` from it.
