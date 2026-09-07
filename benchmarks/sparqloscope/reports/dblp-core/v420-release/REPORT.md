# Reproduce DBLP-core with Fluree v4.2.0

**105/105 queries · 17.5 ms geometric mean · 27.0 ms median query latency.**
[Engine comparison](../REPORT.md) · [Measured requests](../engines/fluree.tsv) ·
[Per-query medians](../engines/fluree_summary.tsv)

Run on September 7, 2026 with the official **v4.2.0 x86_64 Linux binary**,
commit `603974fad5c13efed9d147d214d613849fb43c73`.

| Setting | Value |
|---|---|
| Host | AWS m7a.4xlarge, 16 cores / 64 GB, Ubuntu 24.04 |
| Disk | 250 GB gp3, 6,000 IOPS / 500 MB/s |
| Dataset | DBLP DROPS 2026-06-01, 561,477,456 distinct triples |
| Import | Fresh native import, automatic memory/parallelism settings, Sync durability |
| Query protocol | Local HTTP, TSV responses, no result cache |
| Timing | One warmup + median of three requests per query; 180 s timeout |
| Import wall time | 740.27 s |

On a dedicated host with at least 180 GB free disk space:

```bash
sudo apt-get update
sudo apt-get install -y curl pigz python3 coreutils xz-utils
bash benchmarks/sparqloscope/reproduce-dblp-fluree.sh /path/to/new-run
```

The script pins and verifies the installer, binary and dataset, imports a fresh
ledger, checks its triple count, then runs the committed 105-query harness. It
stops the server on exit and saves results under `/path/to/new-run/results/`.
Shut down any cloud instance you provision after collecting the results.

To regenerate this report and chart from the committed measurements:

```bash
python3 common/generate_report.py benchmarks/sparqloscope/reports/dblp-core
python3 -c 'from common.make_charts import make_dblp_chart; make_dblp_chart()'
```

[Binary manifest](binary-manifest.json) · [Harness SHA-256 hashes](harness-sha256.json) ·
[Dataset source and checksum](../../../datasets/dblp-core/DATASET.md)

Full response bodies and execution logs are archived at
`s3://fluree-benchmark-data/runs/dblp-v420-release-20260907/results.tar.gz`,
under `results/v420-1/`. Archive SHA-256:
`f1dbcd30f7070bb351da50ae3155f07fd6e29bae34487dfb80d84d3f9575f30a`.
