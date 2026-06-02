# Raw run logs — DBLP-KG

Per-run timing logs behind the headline numbers in [`../REPORT.md`](../REPORT.md).
These are the raw measurements; the medians/min/max in
[`../engines/`](../engines/) are derived from them. Published here so the
numbers are inspectable as-is — and so anyone can reproduce and compare against
the actual per-run data rather than just the summary.

| file | engine | rows |
|------|--------|------|
| `fluree_runs.tsv` | Fluree v4.0.5 | 105 queries × 3 timed runs |
| `qlever_runs.tsv` | QLever (latest, `adfreiburg/qlever:latest`) | 105 queries × 3 timed runs |

## Columns

`query_id` · `description` · `run` (1–3) · `status` (HTTP code; 200 = OK) ·
`time_ms` (wall-clock for that single run) · `result_size` (bytes returned) ·
`error`

## Methodology

Captured by [`../../../../../common/run_benchmark.sh`](../../../../../common/run_benchmark.sh):
1 warmup (discarded) + 3 timed runs per query, 300 s timeout. The summary
`median_ms` is the upper-middle of the 3 timed runs. QLever's result cache was
disabled and cleared before each query so it re-executes (matching Fluree, which
has no result cache).

Box: AWS r7a.4xlarge (16c / 128 GB), Ubuntu 24.04. Dataset, hardware, and import
detail: [`../meta.json`](../meta.json) and [`../REPORT.md`](../REPORT.md).

## Reproducing

See [`../../../datasets/dblp-kg/`](../../../datasets/dblp-kg/) (fetch +
checksum + `Qleverfile`) and
[`../../../../../common/engine-setup/`](../../../../../common/engine-setup/) for
per-engine setup, then re-run `common/run_benchmark.sh` against each endpoint.
Absolute times are this-box-only; the engine-vs-engine ratios are the
comparable signal.
