# BSBM engine setup (competitors)

Reproducible setup for the engines we compare against Fluree on BSBM, on the
benchmark box (AWS m7a.4xlarge, 16c / 64 GB, Ubuntu 24.04). All engines run
**native** (no Docker) and are driven by the same `bsbmtools-0.2` testdriver, so
the comparison is apples-to-apples on one machine.

## Engine × use-case coverage

| use case | Fluree | Virtuoso 7 | QLever |
|---|:--:|:--:|:--:|
| Explore (full 12-template mix) | ✓ | ✓ | ✗ — no RDF/XML serializer for Q9 `DESCRIBE` / Q12 `CONSTRUCT` |
| Explore (SELECT-only subset) | ✓ | ✓ | ✓ |
| Business Intelligence | ✓ | ✓ | ✓ |
| Explore-and-Update | ✓ | ✓ (grant `SPARQL_UPDATE`) | ✗ — read-only index (UPDATE is experimental, degrades, can crash) |

The BSBM driver hardcodes `Accept: application/sparql-results+xml` (SELECT) and
`application/rdf+xml` (CONSTRUCT/DESCRIBE). QLever only emits Turtle for
CONSTRUCT/DESCRIBE, so it cannot run the standard Explore mix — hence the
**SELECT-only Explore subset** (`usecases/explore-select/`, drops Q9+Q12), run on
*all three* engines for a fair 3-way read comparison.

## Virtuoso 7

- `setup-virtuoso.sh` — apt-install `virtuoso-opensource-7`, tune `virtuoso.ini`
  for 64 GB (NumberOfBuffers=5.45M per OpenLink guidance), allow the data dir,
  raise server threads, **disable `MaxQueryCostEstimationTime`** (default 400 makes
  Virtuoso refuse the heavy BI queries on a pessimistic estimate), set the BSBM
  default graph, restart (handling the stale-lock pitfall).
- `load-virtuoso.sh <scale> <count>` — split the `.nt` into 16 chunks + 16
  parallel `rdf_loader_run()` into graph `http://bsbm.org/<scale>`.
- Drive: `testdriver ... -dg http://bsbm.org/<scale> http://localhost:8890/sparql`.
- Update use case: `GRANT SPARQL_UPDATE TO "SPARQL";` then drive with `-u <endpoint>`.

## QLever

- `setup-qlever.sh` — **build from source** (the apt repo `packages.qlever.dev`
  returns 403 from AWS; Docker would add an unfair overhead). Uses the official
  Dockerfile dep list + cmake flags → `~/qlever-src/build/{qlever-index,qlever-server}`.
- `load-qlever.sh <scale>` — build a per-scale index from `td_<scale>/dataset.nt`.
- Serves vanilla SPARQL-over-HTTP at the server root `/` (not `/sparql`); SELECT
  returns `sparql-results+xml` via Accept negotiation.

## Methodology notes

- **Deep warm-up for Explore** (`-w 200`): both Virtuoso (44 GB internal buffer
  pool) and Fluree-at-scale (OS page cache) need warming to reach steady state;
  shallow warm-up produced non-monotonic noise. BI/Update use the lighter warm-up
  they can afford (BI queries run 10–60 s; deep warm-up is impractical and BI is
  compute-bound, not cache-bound).
- See `../reports/*/REPORT.md` for the methodology context on the published BSBM
  numbers (the famous ~47k QMpH is a 2013 256 GB-cluster run; our deep-warm
  Virtuoso ~7.4k reproduces the 2011 commodity figure of 7,352).
