# WGPB v4.2.7 evidence

These files accompany the November 14, 2026 [report](../REPORT.md).

| File | Contents |
|---|---|
| [artifacts.tar.gz](artifacts.tar.gz) | Verified archive: 850 queries, runner, summarizer and run script, raw timings for the reported pass and the confirmation pass, all 2,550 measured TSV responses of the reported pass, TI3-40 probe and validation lookups, answer comparison, import log and timing, telemetry and server records |
| [archive-manifest.json](archive-manifest.json) | Archive size, SHA-256 and collection time |
| [build.json](build.json) | Release version, toolchain, build profile and features |
| [ti3-validation.json](ti3-validation.json) | Validation of all three source triples for each of 1,000 distinct TI3-40 solutions |
| [answer-comparison.json](answer-comparison.json) | First measured response of each of the 850 queries compared with a reference response from the same retained store: all byte-for-byte identical |
| [import-reconciliation.json](import-reconciliation.json) | COUNT, index count, duplicate input records and total input records |
| [chunks-verified.json](chunks-verified.json) | Input shard count and shard archive checksum |
| [ledger-size.txt](ledger-size.txt) | Retained ledger size recorded after import |

The answer comparison is a consistency check, not a performance comparison or an
independent reference engine; its reference responses are not part of this archive.
The publication verifier independently rechecks the TI3-40 source triples from the
archived diagnostic responses. TI3-40 validation uses the separate JSON probe; the
timed suite uses TSV serialization.

From the repository root, verify the archive and published results without extraction:

```bash
python3 benchmarks/wgpb/reports/wikidata-all/verify_results.py
```

For manual inspection, extract the archive into a new scratch directory. It contains
`results/full.tsv`, `results/full_summary.tsv`, `results/full-outputs/`,
`results/confirm-sweep.tsv`, `results/target-json/`, `results/ti3-validation/`,
`import/`, `queries/` and the run helpers. `validate-ti3.py` can repeat the
subject-bound lookups against a running database:

```bash
python3 validate-ti3.py \
  --endpoint http://127.0.0.1:8090/v1/fluree/query/wikidata:main \
  --response results/target-json/TI3-40-run0.json \
  --output ti3-validation-replay
```

The archived run script records the original run's absolute paths. Use the portable
query commands in the [WGPB README](../../../README.md#running) for a new run.
