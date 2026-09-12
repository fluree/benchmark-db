# WGPB v4.2.1 evidence

These files accompany the September 12, 2026 [report](../REPORT.md).
The publication copies come from the local run
`runs/subquery-unbound-5529b53-20260912`; the publication does not require that
untracked run directory to be present.

| File | Contents |
|---|---|
| [artifacts.tar.gz](artifacts.tar.gz) | Original verified archive: 850 queries, runner and summarizer, server controls, raw timings, all 2,550 measured TSV responses, targeted checks, diagnostic queries/responses, telemetry and server records |
| [archive-manifest.json](archive-manifest.json) | Archive size (4,097,469 bytes), SHA-256 and collection time |
| [build.json](build.json) | Captured source commit, source archive and binary hashes, build command, compiler and linker flags |
| [ti3-validation.json](ti3-validation.json) | Validation of all three source triples for each of 1,000 distinct TI3-40 solutions |
| [answer-comparison.json](answer-comparison.json) | Collected consistency check: first measured response for each of 849 queries matched its retained reference byte for byte |
| [import-reconciliation.json](import-reconciliation.json) | COUNT, index count, duplicate input records and total input records |
| [chunks-verified.json](chunks-verified.json) | Input shard count and shard archive checksum |
| [ledger-size.txt](ledger-size.txt) | Retained ledger size recorded after import |

The build and server records preserve their original captured version strings;
the report uses the release designation **v4.2.1**. The full source commit and
executable SHA-256 identify the measured binary. Import evidence was collected
September 8 from the same retained store; import metrics are not v4.2.1 timings.

The answer comparison is validation evidence, not a performance comparison or an
independent reference engine. Its reference responses remain in the local retained
run; they are not part of this archive. The publication verifier can independently
recheck the TI3-40 source triples using the archived diagnostic responses, but cannot
repeat that 849-query comparison without those reference responses. TI3-40 validation
uses the separate JSON probe; the timed suite uses TSV serialization.

From the repository root, verify the archive and published results without extraction:

```bash
python3 benchmarks/wgpb/reports/wikidata-all/verify_results.py
```

For manual inspection, extract the archive into a new scratch directory. It contains
`results/full.tsv`, `results/full_summary.tsv`, `results/full-outputs/`,
`results/target-json/`, `results/ti3-validation/`, `queries/` and the run helpers.
`validate-ti3.py` can repeat the subject-bound lookups against a running database:

```bash
python3 validate-ti3.py \
  --endpoint http://127.0.0.1:8090/v1/fluree/query/wikidata:main \
  --response results/target-json/TI3-40-run0.json \
  --output ti3-validation-replay
```

The archived helpers record the original run's absolute paths. Use the portable
query commands in the [WGPB README](../../../README.md#running) for a new run.
