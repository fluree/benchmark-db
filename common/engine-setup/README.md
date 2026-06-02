# Engine setup (native, this environment)

How to stand up each SPARQL engine for the SPARQLoscope benchmark on a fresh
**AWS m7a.4xlarge** (16 vCPU AMD EPYC Zen4 / 64 GB / gp3, Ubuntu 24.04) — the box
we benchmark DBLP-core on. One file per engine here; this page covers what they
share.

> **All engines run NATIVE, not in Docker.** The SPARQLoscope authors recommend
> this (containerization overhead distorts results — see their `docs/setup.md`),
> so we build/install each engine directly on the host. (The old Docker-based
> QLever recipe is gone; `qlever.md` is now the native one.)

## Shared: the dataset (from S3)

We host the benchmark datasets publicly in S3 so a box can self-provision in
seconds (no GitHub auth, no slow upstream):

```bash
# DBLP-core (~561.5M distinct triples; 4.7 GB gz → ~73.5 GB .nt)
curl -sSL -o dblp.nt.gz https://fluree-benchmark-data.s3.amazonaws.com/dblp-core/dblp-2026-06-01.nt.gz
pigz -dk dblp.nt.gz            # -> dblp.nt   (N-Triples; valid Turtle subset)
cp dblp.nt dblp.ttl           # some importers dispatch on .ttl
```

(The bucket policy makes `fluree-benchmark-data/*` world-readable. `dblp-kg/` and
`wikidata-truthy/` live there too. To *upload* from a box: install awscli v2 and
drop temporary STS creds — `aws sts get-session-token` — in `~/.aws/credentials`.)

## Shared: the box

```bash
# AMI ami-0fbcf351e82d18381 (Ubuntu 24.04), key qlever-test, SG sg-08f885d356d61376d
aws ec2 run-instances --instance-type m7a.4xlarge --image-id ami-0fbcf351e82d18381 \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":250,"VolumeType":"gp3","Iops":6000,"Throughput":500}}]' ...
```

Size the volume per engine (index sizes vary a lot — see table). Blazegraph wants
~300 GB; most others fit in 250 GB.

## Shared: running the queries

Use `../run_benchmark.sh` against the engine's SPARQL endpoint. Defaults: 1 warmup
+ median of 3, **300 s timeout with a per-query 300 s budget** (a query that takes
~300 s for one run is measured once, not 3×; a timeout/error stops that query) —
this matches SPARQLoscope's "max 300 s per query". Flags that matter per engine:

- `--endpoint URL` — the SPARQL endpoint (see each engine's file).
- `--post-form` — url-encode as `query=…` instead of an `application/sparql-query`
  body. **Virtuoso needs this**; the others accept the raw body.
- `--default-graph IRI` — adds `default-graph-uri` (Virtuoso, to hit only the dblp
  graph; its no-FROM default unions system graphs).
- `--clear-url URL` — hit before each run to clear a result cache (**QLever only**;
  Fluree/Virtuoso/Jena have none to clear, Oxigraph none).

## Engines at a glance (DBLP-core, this box)

| engine | install | index/load | endpoint | index size | notes |
|---|---|---|---|---|---|
| [Fluree](fluree.md) | build (Rust) | `fluree create --from` | `:8090/v1/fluree/query/dblp:main` | 27 GB | count fastpath |
| [QLever](qlever.md) | native binaries (from image) | `qlever index` | `:7015` | 9.4 GB | `ulimit -n` + `STXXL_MEMORY` |
| [Virtuoso](virtuoso.md) | apt | `isql` bulk load (split+parallel) | `:8890/sparql` | 17 GB | `--post-form --default-graph` |
| [Jena](jena.md) | tarball + JDK21 | `tdb2.xloader` (slow) | `:3030/dblp/sparql` | 54 GB | — |
| [Blazegraph](blazegraph.md) | jar + JDK11 | chunked `LOAD` | `:9999/blazegraph/namespace/kb/sparql` | 82 GB | — |
| [MillenniumDB](millenniumdb.md) | build (C++/CMake) | `mdb import` | `:1234/sparql` | 19 GB | scale buffers to RAM |

Record each engine's version/commit, import time (till-ready), peak RAM, index
size, and the dataset snapshot in the dataset's `reports/<ds>/meta.json`.
