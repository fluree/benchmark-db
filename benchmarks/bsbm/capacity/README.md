# BSBM capacity protocol

This is the protocol behind the published [Fluree v4.2.1 results](../README.md) (September 2026). It uses the same BSBM queries and parameter generator with a **transport-only HTTP keepalive patch**. The original toolkit JAR remains intact. Historical short-run results use a different measurement protocol.

Use the [engine setup instructions](../engines/README.md) for identical database resources and a separate generator per database. Generate the same scale on both hosts and verify its SHA256. Install JDK 21 on the generator, then:

```bash
python3 benchmarks/bsbm/capacity/prepare-driver.py
```

This compiles only `NetQuery.java` from the verified toolkit ZIP into a separate class directory. It saves the patch and compiled class hash. Responses are consumed and closed so HTTP connections can be reused. Query semantics and result serialization are unchanged. The driver uses a 24-GiB heap, WARN logging, seed 808080 and a 300-second per-query timeout. Every client count, including one, uses `-mt` and the driver's measured wall time.

## Explore and SELECT-only reads

Full Explore has **25 executions across 11 active templates**; the supplied mix does not execute Q6. The SELECT subset removes Q9/Q12 and has **20 executions per mix**. Use full Explore for Fluree/Virtuoso and the identical SELECT subset for all three engines.

For each scale and workload, run a common qualification cell with c1, 1,000 warmup mixes and 100 measured mixes. Compare result-count summaries across engines; RDF/XML byte counts are not comparable across serializers. Full result semantics require review beyond counts.

Example on the separate generator, against a Virtuoso 1M host:

```bash
export DB_PRIVATE_IP=10.0.0.10  # replace with your database host's private IP
export BSBM_DATA="$PWD/benchmarks/bsbm/datasets/bsbm-1m/td"
python3 benchmarks/bsbm/capacity/run-cell.py \
  --engine virtuoso --data "$BSBM_DATA" \
  --endpoint "http://$DB_PRIVATE_IP:8182/sparql" --graph http://bsbm.org/ \
  --workload explore --clients 1 --warmups 1000 --runs 100 \
  --minimum-seconds 0 --output results/virtuoso-1m-explore-qualification
```

For QLever, use `--engine qlever`, endpoint `/`, `--workload select` and omit `--graph`. For Fluree, use `--engine fluree`, endpoint `/v1/fluree/query/bsbm:main` and omit `--graph`.
The v4.2.1 results use the source builds listed in the [BSBM README](../README.md#build-and-environment),
`FLUREE_STORAGE_FSYNC=1`, `FLUREE_INDEXING_ENABLED=true`,
`FLUREE_REINDEX_MIN_BYTES=2097152`, and server `--log-level warn`. Set those environment
variables for both import and serving.

Sweep **1, 4, 8, 16, 32, 64 clients**. For every point:

1. Pilot with 1,000 warmup mixes. The refresh uses `min(50000, max(1000, ceil(qualification_QMpH / 3600 × 20 × clients)))` measured mixes. Set `--minimum-seconds 0` for this pilot.
2. Freeze the measured mix count before recorded repetitions: `min(400000, max(1000, ceil(pilot_QMpH / 3600 × 180 / 100) × 100))`. This targets 180 measured seconds; slower workloads may run longer because of the minimum count.
3. Run that count three times, still with 1,000 warmup mixes. Use unique output prefixes and the default minimum accepted duration of 120 seconds. Report the median and range. Flag throughput spread above 5%, errors, timeouts, insufficient duration or changed result-count summaries for review.
4. Extend to 128 clients only if the c64 median exceeds c32 by more than 5%. Check generator CPU, heap/GC and network headroom before calling a plateau a database limit.

Example recorded cell, replacing the illustrative count with the calibrated value:

```bash
python3 benchmarks/bsbm/capacity/run-cell.py \
  --engine virtuoso --data "$BSBM_DATA" \
  --endpoint "http://$DB_PRIVATE_IP:8182/sparql" --graph http://bsbm.org/ \
  --workload explore --clients 32 --warmups 1000 --runs 10000 \
  --output results/virtuoso-1m-explore-c32-r1
```

Each invocation writes raw XML, console/error output, GC log, resource usage and a JSON record containing the command, elapsed time, counts and validation. A nonzero exit indicates invalid or insufficient-duration results; do not publish those as successful-throughput figures.

## Business Intelligence

Run BI at **1M, 100M and 200M**, with 1/4/8/16/32 clients. Use `--workload bi`, two warmup mixes, and a c1 qualification with two measured mixes. BI has **15 query executions per mix** across eight templates.

For each client count, pilot with `max(2, 2 × clients)` measured mixes. Freeze `max(2 × clients, ceil(pilot_QMpH / 3600 × 180))` for three recorded repetitions. The concurrency floor takes precedence over duration: large BI cells can take hours. Three mixes at 32 clients cannot exercise 32 measured workers. Preserve timeout/error cells as censored results; exclude them from successful-throughput rankings. A cell process has a three-hour watchdog.

## Explore-and-Update

Run Update at **1M only**, on Fluree and Virtuoso. The mix has **30 operations**, including five updates; mixed-workload QPS is not write TPS.

Use 1/4/8/16/32/64 clients and three repetitions of **400 measured mixes plus two mutating warmup mixes**. This consumes 804 of the standard 1,000 insert payloads. The runner rejects exhaustion rather than allowing empty inserts. These are fixed-work mutation measurements; use `--minimum-seconds 0` and disclose their durations rather than describing them as sustained 180-second runs.

Before testing, stop the database and take a copy of the fully imported, untouched storage directory. Restart it for a separate durability smoke, then restore the untouched copy before **every** Update repetition. Fluree's snapshot is the directory containing `.fluree`; Virtuoso's is `$VIRTUOSO_HOME/data`. Both servers must be stopped while copying/restoring. Keep copies outside the active directory. Do not reuse a mutated graph between client counts or repetitions.

After each restore, verify COUNT and run a read-only SELECT preparation at the same client count (1,000 warmup + 100 measured mixes). Then run Update. Supply `--update-endpoint`: Fluree uses `/v1/fluree/update/bsbm:main`; Virtuoso uses `/sparql`, with `--graph http://bsbm.org/` for both reads and updates. Keep Fluree fsync/indexing enabled. Virtuoso's startup helper enables transaction-log fsync and the loader grants graph write permission. Record acknowledged durability settings with the result.

Perform write probes outside the final read measurements; deleting their visible triples does not necessarily restore the engine's internal storage history. Reimport or restore untouched storage before read benchmarking after a write probe.

## Telemetry and artifacts

On both hosts, collect `pidstat -h -u -r -d -w -p ALL 2`, `mpstat -P ALL 2` and `sar -n DEV 2` into separate log files. Save timestamps, CPU model, memory size, OS/kernel, engine version, effective configuration and dataset hashes. Retain the toolkit ZIP hash, generated driver patch/class identity, all raw cell outputs and the calibration decisions. Keep one active measured workload per database/generator pair.

QPS is `QMpH × operations_per_mix / 3600`. Retain the distinction between engine-version changes and measurement-protocol changes when comparing against historical reports.
