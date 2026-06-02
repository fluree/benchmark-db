# Dataset: DBLP-core (standard bibliography, no citations)

The **standard DBLP RDF bibliography** — the dataset the SPARQLoscope DBLP query
set was designed for, *without* the OpenCitations citation data that the larger
[`../dblp-kg/`](../dblp-kg/) tar adds. ~574 M triples.

## Pinned snapshot (stable archive)

DBLP's `latest` file at <https://dblp.org/rdf/dblp.nt.gz> is overwritten
continuously (it carries today's date), so it is **not** reproducible on its own.
We instead pin a **dated monthly archive** on the Dagstuhl Research Online
Publication Server (DROPS), which keeps every monthly release permanently with a
DOI. This gives a stable, citable URL we (and anyone reproducing) can point at
forever — and means we don't duplicate ~5 GB into this repo.

> We pin the **latest stable monthly archive at the time** (`2026-06-01`), not a
> specific paper version. The goal is a durable, reproducible reference, not
> bit-for-bit comparability with the SPARQLoscope paper's 2024 dump — see
> caveats. DBLP publishes one archived release per month (`YYYY-MM-01`), DOI-
> tracked back to October 2021.

| Field | Value |
|-------|-------|
| Release | `dblp-2026-06-01` (latest stable monthly DROPS archive when pinned) |
| Format | RDF / N-Triples (`.nt.gz`) — syntactic subset of Turtle, imports as-is |
| URL | `https://drops.dagstuhl.de/storage/artifacts/dblp/rdf/2026/dblp-2026-06-01.nt.gz` |
| DOI | `10.4230/dblp.rdf.ntriples.2026-06-01` |
| Triples | **574,218,804** (measured N-Triples lines; ~73.5 GB uncompressed) |
| Size (`.nt.gz`) | 5,083,386,634 bytes (~4.73 GB) — used as an integrity pre-check |
| SHA-256 (`.nt.gz`) | `6a1edc1b7aebcd7a581bc4313243029952af4af0fbf900e4126a72d6deb92309` |

`fetch-data.sh` downloads this `.nt.gz` (parallel range requests — DROPS is
single-stream throttled), verifies the byte size, prints/records the SHA-256, and
decompresses it to `data/dblp.ttl`. N-Triples is a syntactic subset of Turtle, so
the `.ttl` extension routes it to Fluree's Turtle importer unchanged.

### Why `.nt.gz` and not `.ttl.gz`

DBLP ships the archive as N-Triples. It repeats every full IRI on every line (no
`@prefix`, no subject grouping), so it compresses ~2× larger than the equivalent
Turtle (`dblp.ttl.gz` ≈ 2.1 GB vs `dblp.nt.gz` ≈ 4.7 GB) — same graph, same
triple count. We use N-Triples because it is the format DROPS archives with a DOI,
and because its lack of inline `@prefix` lets **QLever parse it in parallel**
(the [`../dblp-kg/`](../dblp-kg/) shards could not — each shard had its own
`@prefix`, forcing a slow sequential parse).

## How it's loaded

- **Fluree:** `fluree create dblp --from data/dblp.ttl`.
- **QLever:** see [`Qleverfile`](Qleverfile) and `../../../../common/engine-setup/qlever.md`.
  Unlike the KG tar, this single N-Triples file indexes with a **plain
  `qlever index`** — no `--parallel-parsing false`, and far less merge memory.

## ⚠️ Comparability

- This is the **core DBLP bibliography** (no OpenCitations citations), so it is the
  intended shape for the SPARQLoscope DBLP queries. Engine-vs-engine results on
  one box are directly comparable.
- It is **not** the exact dump the SPARQLoscope paper (ISWC 2025) evaluated (that
  used DBLP `2024-04-01`, ~400 M triples). Absolute per-query result *counts* will
  not match the paper's published reference yaml; the schema/query shapes do.
- DBLP grows over time, so a future re-pin to a newer monthly archive will shift
  counts again. The pin above is what makes a run reproducible.

## Sources

- SPARQLoscope (ISWC 2025): <https://purl.org/ad-freiburg/sparqloscope>
- DBLP latest (rolling) dumps: <https://dblp.org/rdf/>
- DBLP dump releases have a DOI / archived since Oct 2021: <https://blog.dblp.org/2024/12/02/dblp-dump-releases-now-have-a-doi/>
- Archived monthly RDF/N-Triples releases (DROPS collection): <https://drops.dagstuhl.de/entities/collection/10.4230/dblp.rdf.ntriples>
