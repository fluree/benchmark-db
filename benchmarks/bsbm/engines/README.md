# BSBM engine setup

These scripts reproduce the **September 2026 refresh configuration** on Ubuntu 24.04 amd64. That refresh is in progress. The [published June comparison](../reports/engine-comparison/REPORT.md) used older releases and a different driver configuration; its numbers are not results from this setup.

Use a dedicated database host per engine and scale: **m7a.4xlarge, 16 vCPU, 64 GiB**, 500-GB gp3 volume at 6,000 IOPS and 500 MiB/s. Each active database has a separate **m7a.2xlarge, 8 vCPU, 32 GiB** load generator in the same subnet/AZ. The generator uses a 150-GB gp3 volume with the same I/O settings. Run one measured workload per pair at a time. Allow the generator to reach the database's private port 8182.

| Engine | Pinned release | Installation |
|---|---|---|
| Virtuoso Open Source | [7.2.17](https://github.com/openlink/virtuoso-opensource/releases/tag/v7.2.17), commit `c4fd28e38e0abe9b6c9841409da29c27878d8ac5` | Official native Linux release; SHA256 checked |
| QLever | [0.6.0](https://github.com/ad-freiburg/qlever/releases/tag/v0.6.0), commit `6c5861a6526d7d7ae77735d09339ee0825f0c001` | Official Ubuntu `qlever-bin_0.6.0-1~noble~24.04_amd64.deb`; SHA256 checked |

No moving source checkout is required. The exact download URLs, hashes, effective settings and binary identities are recorded by the scripts. Virtuoso's Ubuntu `isql-vt` package supplies only the administration client; the database process is the official 7.2.17 binary. The release's bundled client requires ncurses 5, which is unavailable in the benchmark's Ubuntu image.

## Generate the same inputs

From the repository root, on both the database and generator hosts:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk-headless curl unzip python3 sysstat
bash benchmarks/bsbm/datasets/bsbm-1m/fetch-data.sh
python3 benchmarks/bsbm/engines/check-dataset.py 1m \
  benchmarks/bsbm/datasets/bsbm-1m/td/dataset.nt --output dataset-1m.json
# Substitute bsbm-100m or bsbm-200m for the larger scales.
```

Use the complete `td/` directory on the generator: it contains the parameter pools as well as the RDF data. Engine loaders verify the pinned dataset hash and fail on drift. Expected graph counts are **724,101 / 100,000,748 / 200,031,975**. The nominal 1M input holds out 1,000 insert payloads for Update.

## Virtuoso

On each fresh database host, choose one scale:

```bash
export VIRTUOSO_HOME="$HOME/bsbm-engines/virtuoso"
export BSBM_DATA="$PWD/benchmarks/bsbm/datasets/bsbm-1m/td"
export BSBM_GRAPH=http://bsbm.org/
bash benchmarks/bsbm/engines/setup-virtuoso.sh "$BSBM_DATA"
bash benchmarks/bsbm/engines/load-virtuoso.sh 1m
```

The 64-GiB profile uses 5,450,000 buffers, 4,000,000 dirty buffers, 256 client connections, persistent HTTP connections and a 600-second server query limit. Cost-estimate rejection is disabled; the driver enforces the common 300-second timeout. Query memory remains 2 GiB. The effective INI is saved under `$VIRTUOSO_HOME/metadata/`.

The load script initializes the generator's datatypes before loading. At 200M it uses one loader session to avoid the observed 7.2.17 concurrent datatype-registration failure. At smaller scales it uses 16. Explicitly failed chunks get one serial retry, and the final graph COUNT must match exactly. This affects import setup, not the timed query workload.

Always pass **`--graph http://bsbm.org/`** to the capacity driver. An unscoped query can include Virtuoso's system graphs. Updates require both the `SPARQL_UPDATE` role and graph-specific read/write permission; the loader sets both.

`virtuoso-control.sh start` explicitly enables transaction-log fsync with `__dbf_set('dbf_log_fsync', 1)` on every start and records the effective value. `CheckpointSyncMode=2` alone does not enable per-transaction log fsync. The refresh separately verified successful sync calls before each acknowledged smoke-test insert. See [Virtuoso's transaction-log implementation](https://github.com/openlink/virtuoso-opensource/blob/v7.2.17/libsrc/Wi/log.c) and [graph permission documentation](https://docs.openlinksw.com/virtuoso/fn_rdf_graph_user_perms_set/).

```bash
bash benchmarks/bsbm/engines/virtuoso-control.sh stop
bash benchmarks/bsbm/engines/virtuoso-control.sh start
```

Stop checkpoints the database and stops only the PID managed by this installation. Setup refuses to overwrite an existing database.

## QLever

On a separate fresh database host:

```bash
export QLEVER_HOME="$HOME/bsbm-engines/qlever"
export BSBM_DATA="$PWD/benchmarks/bsbm/datasets/bsbm-1m/td"
bash benchmarks/bsbm/engines/setup-qlever.sh
bash benchmarks/bsbm/engines/load-qlever.sh 1m
bash benchmarks/bsbm/engines/qlever-control.sh start 1m
```

The index uses native N-Triples input and patterns. The server runs with 64 simultaneous queries, a 40-GiB query/cache memory budget, WARN logging and a 600-second server timeout. The common driver timeout remains 300 seconds. COUNT is checked before timing. Query the server root, **`http://DATABASE_PRIVATE_IP:8182/`**, without a default-graph override.

QLever 0.6.0 supports updates and optional persistence; the old description of it as a read-only engine is obsolete. Its tested canonical full-Explore probe fails the driver's required RDF/XML response path. The current comparison therefore runs the **same SELECT subset and BI** on all three engines. QLever's durable Update coverage has not been established; do not equate `--persist-updates` with fsync before acknowledgement. See [QLever's current update options](https://github.com/ad-freiburg/qlever/blob/v0.6.0/src/ServerMain.cpp).

```bash
bash benchmarks/bsbm/engines/qlever-control.sh stop
```

## Run and retain the measurements

Use the [capacity driver and protocol](../capacity/README.md), not the historical short `run-matrix.sh` defaults. It documents warmup, concurrency, calibration, three repetitions, result/error checks and the bounded Update workload. Keep binary/configuration metadata, dataset hashes, the driver patch/class hash, exact commands, raw XML/logs and CPU/memory/network telemetry with the report.

Archive and verify the results before terminating cloud instances. Verify instance termination and deletion of their benchmark volumes; stopping a database process alone does not stop EC2 charges. The current AWS run has automatic archive, termination and volume-verification guards, with a 24-hour instance backstop.
