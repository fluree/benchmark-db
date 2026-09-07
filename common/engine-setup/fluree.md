# Fluree (native)

DBLP-core uses the official **v4.2.0 Linux x86_64 release binary**. Other datasets
record their measured Fluree version in their own `meta.json`.

## Reproduce DBLP-core

The [pinned run instructions](../../benchmarks/sparqloscope/reports/dblp-core/v420-release/REPORT.md)
cover installation, hardware, dataset and binary checksums, import, and timing:

```bash
bash benchmarks/sparqloscope/reproduce-dblp-fluree.sh /path/to/new-run
```

## Install and run manually

```bash
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/fluree/db/releases/download/v4.2.0/fluree-db-cli-installer.sh | sh
source "$HOME/bin/env"
fluree --version  # fluree 4.2.0

mkdir fluree-run && cd fluree-run
fluree init
fluree create dblp --from /path/to/dblp.nt
fluree server run --listen-addr 127.0.0.1:8090
```

On the measured 64 GB host, automatic import settings selected a 50,332 MB
memory budget, parallelism 13 and 768 MB chunks. The import produced
561,477,456 distinct triples in 740.27 seconds of process wall time.

From another terminal in the benchmark repository:

```bash
common/run_benchmark.sh \
  --endpoint http://127.0.0.1:8090/v1/fluree/query/dblp:main \
  --queries benchmarks/sparqloscope/queries -w 1 -r 3 -t 180 \
  -o /path/to/results/fluree.tsv
```

Fluree has no query-result cache; no cache-clearing request is needed. These
measurements use the native server over HTTP, with default cache settings and
Sync storage durability. Stop the server after collecting the results.
