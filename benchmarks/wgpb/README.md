# Wikidata Graph Pattern Benchmark (WGPB)

**Fluree v4.2.1 completed 850/850 queries with a 20.165 ms geometric mean** on
September 12, 2026, against 21.127 billion distinct Wikidata triples on one AWS
`r7a.8xlarge` (32 vCPU / 256 GiB). The median was 16.443 ms; 99.2% of queries
completed in under one second. No errors or timeouts occurred.

[Full report](reports/wikidata-all/REPORT.md) ·
[Per-query timings](reports/wikidata-all/engines/fluree_summary.tsv) ·
[Build, validation and response evidence](reports/wikidata-all/evidence/README.md)

The workload has 850 basic graph pattern queries: 17 join shapes × 50 predicate
instantiations, covering joins, paths, squares, stars and triangles. Each query is
`SELECT * ... LIMIT 1000` over Wikidata predicates. This benchmark measures Fluree
only. The exact query set is in [queries/](queries/).

Query-set source: Hogan, Riveros, Rojas and Soto, *A Worst-Case Optimal Join
Algorithm for SPARQL* (ISWC 2019), [WGPB on Zenodo](https://zenodo.org/record/4035223).

## Layout

- `queries/` — the 850 `.sparql` files, named `<family>-<nn>.sparql`
  (J3/J4 joins, P2–P4 paths, S1–S4 squares/4-cycles, T2–T4 subject out-stars,
  TI2–TI4 object in-stars, Tr1/Tr2 triangles; 50 each).
- `reports/wikidata-all/` — results against the full Wikidata all-dump
  (21.127B distinct triples; 21.512B input records): `REPORT.md`, `meta.json`, raw timings in `engines/`.

## Running

Use the v4.2.1 source build identified in the [report](reports/wikidata-all/REPORT.md#3-hardware-build-and-timing-protocol)
and an imported `wikidata` ledger. From the ledger directory, start the server:

```bash
FLUREE_CACHE_MAX_MB=88311 fluree server run \
  --listen-addr 127.0.0.1:8090 --log-level warn
```

The cache setting matches the measured 256 GiB host. In a separate terminal, from
the repository root, load the ledger before timing, then run the suite:

```bash
curl -fsS --max-time 600 -H 'Content-Type: application/sparql-query' \
  -H 'Accept: application/sparql-results+json' \
  --data 'SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 1' \
  http://127.0.0.1:8090/v1/fluree/query/wikidata:main > startup-prime.json
# The measured run also executed this separate JSON probe before the full suite.
curl -fsS --max-time 120 -H 'Content-Type: application/sparql-query' \
  -H 'Accept: application/sparql-results+json' \
  --data-binary @benchmarks/wgpb/queries/TI3-40.sparql \
  http://127.0.0.1:8090/v1/fluree/query/wikidata:main > TI3-40-probe.json
bash common/run_benchmark.sh \
  --endpoint http://127.0.0.1:8090/v1/fluree/query/wikidata:main \
  --queries benchmarks/wgpb/queries -r 3 -w 1 -t 120 \
  --save-outputs query-outputs -o fluree.tsv
python3 common/summarize.py fluree.tsv > fluree_summary.tsv
```

J4-38 must place `LIMIT 1000` outside the closing `WHERE` brace, as in the published
query file. All triple patterns and predicates are preserved. The archived query
hashes identify the exact inputs used for the measurement.

`common/wgpb_histogram.py fluree_summary.tsv` prints the latency-bucket distribution.

Inspect every query's status in `fluree_summary.tsv`: harness completion does not
mean every query succeeded. `result_size` records response bytes, not row counts.
The [publication verifier](reports/wikidata-all/verify_results.py) checks the saved
samples, summary, query hashes, archive integrity and TI3-40 validation evidence.

## Preserve the imported database

Retain the imported ledger for reruns and debugging. Saved input chunks avoid
re-chunking, but do not avoid the roughly six-hour import of the full graph.

For EC2 runs, set the database volume's **DeleteOnTermination=false** at launch
and use **stop** as the instance-initiated shutdown behavior. After import and
COUNT validation, let all database processes exit, flush pending writes, and take
an EBS snapshot while the database remains quiescent. Wait for the snapshot to
complete before starting benchmark/debug queries. Record its ID, source volume,
region, ledger path, binary hash, and input hashes with the results. Stop compute
after collecting results; retain the volume and snapshot until explicitly cleared
for deletion. A result archive containing timings and logs is not a database backup.

With the retained ledger selected, the CLI can capture a plan
without executing the query:

```bash
fluree query wikidata --direct --explain --format json --sparql \
  -f /path/to/benchmark-db/benchmarks/wgpb/queries/TI3-40.sparql > TI3-40-plan.json
```

Capture plans on the actual Wikidata ledger and outside timed cells. A plan from
a smaller unrelated dataset verifies syntax but does not establish the full-scale
plan or performance. Use `fluree query --explain` for this diagnostic.
