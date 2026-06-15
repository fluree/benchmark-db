# Wikidata Graph Pattern Benchmark (WGPB)

850 basic graph pattern queries — 17 abstract join shapes × 50 predicate instantiations —
from Hogan, Riveros, Rojas, Soto: *"A Worst-Case Optimal Join Algorithm for SPARQL"*
(ISWC 2019), query set [Zenodo 4035223](https://zenodo.org/record/4035223). The shapes
(joins, paths, squares, subject/object stars, triangles) are chosen to stress join
planning on cyclic and star patterns. Each query is `SELECT * ... LIMIT 1000` over
Wikidata `prop/direct` truthy edges.

## Layout

- `queries/` — the 850 `.sparql` files, named `<family>-<nn>.sparql`
  (J3/J4 joins, P2–P4 paths, S1–S4 squares/4-cycles, T2–T4 subject out-stars,
  TI2–TI4 object in-stars, Tr1/Tr2 triangles; 50 each).
- `reports/wikidata-all/` — results against the full Wikidata all-dump
  (21.5B triples): `REPORT.md`, `meta.json`, raw timings in `engines/`.

## Running

Serve the dataset, then:

```bash
common/run_benchmark.sh \
  --endpoint http://localhost:8090/v1/fluree/query/<ledger> \
  --queries benchmarks/wgpb/queries -r 3 -w 1 -t 120 -o fluree.tsv
python3 common/summarize.py fluree.tsv > fluree_summary.tsv
```

`common/wgpb_histogram.py fluree_summary.tsv` prints the latency-bucket distribution.
