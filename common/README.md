# Benchmark reporting

Standardized, regenerable benchmark reports — one per dataset, comparing engines
side by side. Built to scale from 2 engines to the full SPARQLoscope engine set,
and from DBLP to Wikidata Truthy.

## Layout

```
reports/<dataset>/
  meta.json                      # env, dataset facts, per-engine setup + import facts (hand-authored)
  engines/<engine>_summary.tsv   # output of run_benchmark.sh's summarize (query_id, median_ms, ...)
  correctness.json               # optional: result-equivalence check [[query_id, STATUS, ...], ...]
  REPORT.md                      # GENERATED — do not edit by hand
```

Datasets reported with this generator: `dblp-core` (7 engines) and `wikidata-truthy`
(5 engines), both under `benchmarks/sparqloscope/reports/`. (WGPB is a single-engine
graph-pattern benchmark with its own report under `benchmarks/wgpb/`.)

## Generate

```bash
python3 generate_report.py <benchmark>/reports/<dataset>
```

Reads `meta.json` + every `engines/*_summary.tsv` + `correctness.json`, writes `REPORT.md`.
Engine display order and labels come from the `engines` object in `meta.json`.
Re-run any time the inputs change; the report is fully derived.

## Report format (what the generator emits)

1. **Environment & dataset** — dataset source/version/SHA + size; hardware; method; per-engine version/config.
2. **Import / indexing** — table (time, throughput, peak RAM, index size, gotchas) + phase breakdown per engine.
3. **Query benchmark** — three views:
   - **3a. Aggregates** — passed, arith/geo/median per engine, plus one *geo-mean-slowdown-vs-best* number per engine (the whole-suite standing).
   - **3b. By category** — geo mean per SPARQLoscope family (JOIN, OPTIONAL, MINUS, EXISTS, UNION, GROUP BY, FILTER, Numeric, Date, String/REGEX, Transitive, Dataset-stats, Result-size) + a `fastest` column naming the leader. This is the headline view.
   - **3c. Per query** — full 105, each engine `abs (×best)`, plus a `results` column from the correctness check.
4. **Correctness & caveats** — agreement summary + dataset-specific caveats from `meta.json`.

### Cell convention
Every engine cell in the query grids is **`abs (×best)`** where `×best` = slowdown vs the
**fastest engine in that row** (fastest = `1.0×`, **bolded**). One rule, reads the same with
any number of engine columns — no "× vs whom" ambiguity, no "winner" word.

- **Floor:** rows whose best is below `FLOOR_MS` (10 ms) show absolute only — ratios on
  trivially-fast queries (e.g. a metadata count QLever serves in 0 ms) are noise.
- **Sub-millisecond (0 ms)** results are floored to 1 ms in geo means so they count as "fast"
  rather than being dropped.

## Adding an engine
1. Run `run_benchmark.sh --endpoint <url> [--clear-url <url>] -o results/<engine>.tsv` against it
   (see `engine-setup/qlever.md` for QLever specifics).
2. Copy the `*_summary.tsv` to `reports/<dataset>/engines/<engine>_summary.tsv`.
3. Add an `engines.<engine>` block to `meta.json` (label, version, config, import facts).
4. Re-run the generator. The new engine becomes another column everywhere.

## Notes
- `meta.json` is the only hand-authored input; everything in §3 is computed.
- Keep `engines/*.tsv`, `correctness.json`, and import logs as the regenerable backing data.
- `REPORT.md` is generated — edits will be overwritten.
