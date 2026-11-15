# BSBM 100M: Fluree vs relational databases (MySQL 8.0, PostgreSQL 16)

**Status: internal, unpublished.** Measured November 14–15, 2026. The Fluree build is a pre-release
development build; relabel it to its release version (and re-run the matrix on that release) before
any of this is published. See [Provenance](#provenance).

The Berlin SPARQL Benchmark ships an **official relational version of its Explore use case**: the data
generator writes the same dataset as a SQL dump (`-s sql`), the toolkit includes SQL translations of the
Explore queries (`queries/sql/explore`), and the same test driver runs them over JDBC. That makes BSBM
Explore a like-for-like "RDF vs relational" comparison: same data, same query mix, same seed and
parameters, same driver, same hardware. BSBM's original results (2008–2011) had relational databases far
ahead of every RDF store on this workload.

## Results — Explore (the full 25-query mix)

QMpH = query mixes per hour, median of three ~180 s repeats; every cell valid, zero timeouts.

| Clients | Fluree dev | PostgreSQL 16 | MySQL 8.0 | Fluree v4.2.7 | Fluree dev vs PostgreSQL | vs MySQL |
|--:|--:|--:|--:|--:|--:|--:|
| 1 | **46,966** | 34,120 | 27,389 | 27,308 | +38% | +71% |
| 4 | **188,803** | 124,951 | 99,509 | 109,362 | +51% | +90% |
| 8 | **353,949** | 233,104 | 184,429 | 206,344 | +52% | +92% |
| 16 | **606,813** | 358,754 | 310,552 | 361,558 | +69% | +95% |
| 32 | **783,462** | 358,219 | 322,023 | 435,619 | 2.19× | 2.43× |
| 64 | **778,138** | 353,192 | 319,901 | 433,334 | 2.20× | 2.43× |
| **peak** | **783,462** | 358,754 | 322,023 | 435,619 | 2.18× | 2.43× |

- Fluree (development build) leads both relational engines **at every client count**: +38% over
  PostgreSQL at one client, **2.2× PostgreSQL and 2.4× MySQL at peak**.
- PostgreSQL beats MySQL in every cell and plateaus at ~357k QMpH from 16 clients.
- Fluree v4.2.7 (released) trails PostgreSQL at 1–8 clients, ties at 16 and leads at 32–64; the
  development build is 1.7–1.8× v4.2.7 throughout.

## Results — SELECT subset (Explore minus Q9 DESCRIBE and Q12 CONSTRUCT)

Run only to mirror the SPARQL protocol (the SELECT subset exists so QLever can be compared); Explore is the
comparison that matters.

| Clients | Fluree dev | PostgreSQL 16 | MySQL 8.0 | Fluree v4.2.7 | Fluree dev vs PostgreSQL | vs MySQL |
|--:|--:|--:|--:|--:|--:|--:|
| 1 | **48,691** | 35,519 | 28,564 | 27,644 | +37% | +70% |
| 4 | **193,769** | 128,777 | 101,563 | 111,775 | +50% | +91% |
| 8 | **367,201** | 241,384 | 185,778 | 211,920 | +52% | +98% |
| 16 | **636,462** | 357,559 | 309,315 | 373,626 | +78% | 2.06× |
| 32 | **802,820** | 358,988 | 331,932 | 443,090 | 2.24× | 2.42× |
| 64 | **796,915** | 356,093 | 320,858 | 439,750 | 2.24× | 2.48× |
| **peak** | **802,820** | 358,988 | 331,932 | 443,090 | 2.24× | 2.42× |

## Fluree throughput by server size (Explore)

Development build (sharded leaflet cache), BSBM 100M, peak cell per size. The 16-vCPU row is the full
protocol above; the 32/64-core rows are single 110–135 s cells on an `m7a.16xlarge` pinned with `taskset`
(16 pinned cores reproduced the real 16-vCPU box within 1%: 777,874 vs 783,462). Raw cells and the build
comparison (v4.2.7 → #2404 → #2405 → sharded) are in [scaling/](scaling/).

| Server cores | Peak QMpH | Queries/s | QMpH per core | vs 16 cores |
|--:|--:|--:|--:|--:|
| 16 (`m7a.4xlarge`) | 783,462 | 5,440 | 49.0k | 1.00× |
| 32 (pinned) | 1,512,167 | 10,500 | 47.3k | 1.93× |
| 64 (`m7a.16xlarge`) | 2,551,430 / 2,538,263 | 17,700 | 39.8k | 3.25× |

Not yet measured: 96/192 vCPU (no `m7a.48xlarge` capacity in the zone at the time).

## Setup

| | |
|---|---|
| Hardware | Database: AWS `m7a.4xlarge` (16 vCPU AMD EPYC, 64 GiB), gp3; driver: `m7a.2xlarge`, same AZ. Identical instance types for all three engines (the published Fluree BSBM hosts). |
| Dataset | BSBM 100M (`-pc 284826`), pinned bsbmtools-0.2. Relational: 10 tables, row counts in `config/*/rowcounts`. Fluree: 100,000,748 triples. |
| Driver | bsbmtools-0.2 TestDriver, seed 808080, 300 s query timeout, 1,000 warmup mixes per cell. SPARQL for Fluree (keep-alive patch, as published); JDBC (`Statement`, not prepared) for MySQL (Connector/J 8.4.0) and PostgreSQL (pgJDBC 42.7.4). |
| Protocol | Per client count: a calibration pilot (not reported) sizes three ~180 s repeats; the database is restarted and its row/triple count checked before every cell. Scripts: [scripts/](scripts/). |
| MySQL | 8.0 (Ubuntu 24.04 apt), InnoDB, BSBM's own schema and indexes; `innodb_buffer_pool_size=40G`, binary log off, `O_DIRECT`, `max_connections=1000`. **Plus two secondary indexes we added** on the product–feature and product–type link tables (`config/mysql/extra-indexes.sql`); without them Q5 took >5 s. Full variables: `config/mysql/mysql-variables.tsv`. |
| PostgreSQL | 16.15 (Ubuntu 24.04 apt). Data exported from the loaded MySQL tables (`SELECT … INTO OUTFILE` → `COPY`), so rows are identical; the same indexes as MySQL including the two extras; `VACUUM ANALYZE`. `shared_buffers=16GB`, `effective_cache_size=48GB`, `work_mem=32MB`, `random_page_cost=1.1`, `jit=off`; database collation `C` (= MySQL `utf8mb3_bin` byte order). Non-default settings: `config/postgres/pg-settings.tsv`. |
| Fluree | Default server configuration as published (cache 35% of RAM, fsync on), fresh server per cell. The v4.2.7 column is the published release matrix, which used fixed per-repeat mix counts (~155–185 s repeats) instead of a pilot; same hosts, driver, seed and warmups. |

Correctness: per-query execution and result counts (avg/min/max) match between MySQL and PostgreSQL for
the same mixes, and between Fluree builds. (SQL and SPARQL result counts differ by design for Q9/Q12,
which return rows in SQL and triples in SPARQL.)

Tuning note: if anything the relational side is favoured — tuned memory settings, JIT off, and two
indexes BSBM does not ship. Untested: commercial RDBMSs, prepared statements, PostgreSQL 17/18.

## Provenance

| Label | Build |
|---|---|
| Fluree dev | fluree/db `perf/leaflet-cache-contention` @ `d6951064` (PR #2405 incl. #2404: nested-loop leaflet/leaf skip, sharded leaflet cache, constant-IRI BIND fix), release profile |
| Fluree v4.2.7 | release v4.2.7; runs read in place from [`../v4.2.7/runs/100m`](../v4.2.7/runs/100m) |

## Files

- `summary.tsv`, `per_query.tsv` — built by `collect.py` from `runs/<engine>/*.xml` (driver output, measured repeats only).
- `config/` — engine versions, settings, row counts, table sizes, JDBC driver hashes.
- `scripts/` — setup, server control, cell runner and coordinators used for these runs.
- `scaling/` — per-core-count and per-build cells on the 64-vCPU box (`summary.tsv`, `builds.tsv`, raw cells).
