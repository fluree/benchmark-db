# Dataset: Wikidata Truthy

The second dataset with a published SPARQLoscope reference (alongside DBLP). The
Wikidata **"truthy"** dump is the `wdt:`-style projection of Wikidata: statements
without qualifiers/references, no deprecated statements, and normal-rank
statements only where no preferred-rank statement exists for the same
subject+predicate. Distributed as a single gzipped N-Triples file.

| field | value |
|-------|-------|
| Source | `https://dumps.wikimedia.org/wikidatawiki/entities/latest-truthy.nt.gz` |
| Mirror (pinned) | GitHub release [`wikidata-truthy-source-20260529`](https://github.com/fluree/benchmark-db/releases/tag/wikidata-truthy-source-20260529) (split `.part-*`, <2 GiB each) |
| Snapshot | 2026-05-29 11:17:24 GMT (rolling "latest"; pin the SHA) |
| Size (.nt.gz) | 70,497,233,745 bytes (~70.5 GB compressed; ~700 GB+ uncompressed) |
| SHA-256 (.nt.gz) | `9fb5a16502ac05d9b9aad9f161bfe4e3e9ac514e142d7cf5ae4efd030b9f739a` |
| Triples | ~8B (exact count recorded after import) |

`fetch-data.sh` downloads + size/SHA-verifies the dump. The upstream URL is a
rolling "latest" overwritten weekly, so — exactly as with [`../dblp-kg/`](../dblp-kg/)
— the exact snapshot we benchmark is mirrored as a GitHub release. Use
`fetch-data.sh --mirror` to pull that pinned copy instead of upstream.

## How it's loaded

- **Fluree:** `fluree create wikidata --from <file>`. N-Triples is a syntactic
  subset of Turtle; if the importer dispatches on extension, present the data
  with a `.ttl` extension (or the `.nt.gz` directly if supported) so it routes to
  the Turtle/N-Triples parser. Same graph, same triple count. At ~700 GB
  uncompressed, prefer streaming from `.nt.gz` over fully decompressing if the
  importer allows it.
- **QLever:** see [`Qleverfile`](Qleverfile) and `../../../../common/engine-setup/qlever.md`.
  Single N-Triples file with fully-expanded IRIs (no per-shard `@prefix`), so a
  plain parallel parse works — unlike the dblp-kg shard tar. At ~8B triples the
  index build needs a large sort/merge memory (raise `-m` well above the
  dblp-kg `90G`); sized for the 512 GB box.

## ⚠️ Not the paper's exact snapshot

The published SPARQLoscope table used Wikidata Truthy **as of 2025-04-18**, which
is no longer on the live Wikimedia mirror and is not archived by SPARQLoscope or
QLever (both consume the rolling `latest`). This is therefore:

- The same query set on a **current, larger** snapshot — comparable *between
  engines on the same box*, **not** to the paper's published numbers.
- Per-query result counts will not match the published reference yaml.
