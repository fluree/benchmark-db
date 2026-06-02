# Dataset: DBLP-KG (bibliography + OpenCitations citations)

The dataset the SPARQLoscope DBLP query set is generated against (via its
`Qleverfile`): the DBLP knowledge graph **plus OpenCitations citation data**,
distributed as one tar of gzipped Turtle shards.

| field | value |
|-------|-------|
| Source | `https://sparql.dblp.org/download/dblp_KG_with_associated_data.tar` |
| Snapshot | 2026-05-30 01:16:39 GMT (rolling "latest"; pin the SHA) |
| SHA-256 (.tar) | `963cf2d1483a068ba8460b901c11a3bd3598e22f945aff181f65740754329cba` |
| Size | 6.0 GB tar → 168 `.ttl.gz` shards (~6.1 GB) |
| Triples | ~1,574,283,728 |
| Predicates | 96 |

`fetch-data.sh` downloads + checksum-verifies the tar and unpacks the shards.

## How it's loaded

- **Fluree:** `fluree create dblp --from <shards-dir>`. The shards include one large
  `dblp.ttl.gz` (~24 GB uncompressed); current Fluree imports the directory directly.
- **QLever:** see [`Qleverfile`](Qleverfile) and `../../../../common/engine-setup/qlever.md`.
  Indexing this layout needs `--parallel-parsing false` (each shard carries its own
  `@prefix`) and a raised sort-memory (`-m 90G`).

## ⚠️ Not the published reference dataset

The published SPARQLoscope table uses the **core DBLP bibliography** (~502M triples,
no citations — see [`../dblp-core/`](../dblp-core/)). This KG tar adds ~1B
OpenCitations citation triples, so:

- It is the same query set on a **larger** dataset — comparable *between engines on
  the same box*, **not** to the paper's numbers.
- Per-query result counts will not match the published reference yaml.
- The DBLP *bibliography* portion already contains the stream / `createdBy`
  predicates the queries use — the citations are extra "associated data," not
  required for the queries to return results. (The original confusion: our first
  attempt used a *2024* core that predated those schema predicates.)
