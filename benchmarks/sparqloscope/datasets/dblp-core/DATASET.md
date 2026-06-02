# Dataset: DBLP RDF (frozen snapshot)

Reproducibility hinges on every run using the **same** DBLP dump. DBLP's
"latest" file at <https://dblp.org/rdf/> is overwritten continuously (it carries
today's date), so it is **not** reproducible on its own. Pin a dated snapshot.

## Pinned snapshot

We pin the **same DBLP dump the SPARQLoscope authors used** for their published
ISWC 2025 evaluation, so Fluree's numbers are directly comparable to the engine
results in that paper and on labs.flur.ee. The paper writes "version 02.04.2024";
the actual archived release file is dated **2024-04-01** (no 04-02 file exists).

DBLP publishes stable, dated monthly snapshots with permanent DOIs. Hosting moved
to the Dagstuhl Research Online Publication Server (DROPS) in Dec 2024; **all
RDF/N-Triple releases since October 2021 are archived there**, so 2024-04-01 is
still retrievable.

| Field | Value |
|-------|-------|
| Release | `dblp-2024-04-01` (the version used by the SPARQLoscope paper) |
| Format | RDF / N-Triples (`.nt.gz`) — valid Turtle, imports as-is |
| URL | `https://drops.dagstuhl.de/storage/artifacts/dblp/rdf/2024/dblp-2024-04-01.nt.gz` |
| DOI | `10.4230/dblp.rdf.ntriples.2024-04-01` |
| Triples / predicates | ~390M (per the paper); measured 400,874,695 N-Triples lines, 68 predicates |
| Size (`.nt.gz`) | ~3.85 GB compressed (3,849,294,658 bytes) |
| Size (`dblp.ttl`) | ~47.6 GB uncompressed (51,086,535,515 bytes) |
| SHA-256 (`.nt.gz`) | `c4d05d2af955dd58aec821e6c2a4e9b2556ec9cd3741255cf3741527c4e59028` |

`fetch-data.sh` downloads this `.nt.gz`, verifies its SHA-256, **keeps** the
archive in `data/` (so it can be mirrored as a GitHub Release asset), and
decompresses it to `data/dblp.ttl`. N-Triples is a syntactic subset of Turtle, so
the `.ttl` extension routes it to Fluree's Turtle importer unchanged.

### Why `.nt.gz` is ~3.85 GB but the paper says ~1.8 GB

Same graph, different serialization. The paper quoted the gzipped **Turtle**
size; DBLP's archived monthly releases are **N-Triples**, which repeats every
full IRI on every line (no `@prefix`, no subject grouping) and so compresses
roughly 2× larger. DBLP's current dumps show the same ratio (`dblp.ttl.gz` ≈
2.1 GB vs `dblp.nt.gz` ≈ 4.7 GB). Triple count is identical either way.

## Why this exact version

The SPARQLoscope paper (Bast et al., ISWC 2025) evaluated all engines on **DBLP
version 02.04.2024** (~390M triples, 68 predicates) — the `dblp-2024-04-01`
release. DBLP grows weekly, so a newer dump would have more triples and would
*not* be comparable to those published engine numbers. Matching 2024-04-01 keeps
Fluree's run apples-to-apples.

> Generate `baseline/summary.tsv` from a run on this exact snapshot so your
> committed reference numbers stay apples-to-apples with the paper's engine
> results. A run on any other DBLP dump is not directly comparable.

## Mirror (recommended)

The DROPS download is slow (single-stream throttled to ~250 KB/s; `fetch-data.sh`
works around it with parallel range requests). Mirror the exact `.nt.gz` as a
**Release asset** on `fluree/benchmark-db` and point `FLUREE_DBLP_URL`
at it for fast, durable downloads; keep the DOI here as the canonical, citable
source of truth.

## Sources

- SPARQLoscope (ISWC 2025), pins DBLP 02.04.2024: <https://purl.org/ad-freiburg/sparqloscope>
- DBLP latest dumps: <https://dblp.org/rdf/>
- DBLP releases now have a DOI / archived since Oct 2021: <https://blog.dblp.org/2024/12/02/dblp-dump-releases-now-have-a-doi/>
- Archived monthly RDF/N-Triples releases (DOI): <https://doi.org/10.4230/dblp.rdf.ntriples>
