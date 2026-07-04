# Fluree vs Amazon Neptune — RDF / SPARQL Comparison

A feature-set and performance comparison for RDF/semantic workloads. The feature
matrix is verified against each system's documentation and (for Fluree) the
source tree; the performance plan reuses this repo's
[DBLP-core SPARQLoscope harness](README.md) on an instance size both engines can
run natively.

> **Scope.** This compares the two as **RDF triple stores / SPARQL engines**.
> Both are multi-model: Neptune also speaks property graph (Gremlin + openCypher);
> Fluree also speaks JSON-LD and openCypher and is an immutable, policy-enforcing
> ledger. Those non-SPARQL strengths are noted but not the focus.

---

## TL;DR

- **Standards core (SPARQL 1.1 Query + Update, named graphs, federation, the common
  RDF serializations):** both cover it. Neptune is a mature, fully-compliant SPARQL
  1.1 engine; Fluree is ~78% on the W3C SPARQL 1.1 test suite with a few operator
  gaps. For the 105-query SPARQLoscope suite, both answer the workload.
- **Where Fluree is differentiated:** native **reasoning** (RDFS / OWL 2 QL / OWL 2 RL
  / Datalog), native **SHACL**, **query-time time-travel**, an **immutable,
  cryptographically-signed commit chain**, **triple-level access policy**, and native
  **vector + BM25** search — all in-engine.
- **Both are multi-model.** Neptune queries the same store as RDF/SPARQL **and** as a
  property graph via **Gremlin + openCypher**. Fluree queries the same store as
  RDF/SPARQL, **JSON-LD**, **and openCypher** (a broad openCypher-9 surface). The one
  property-graph language Neptune has that Fluree doesn't is **Gremlin**.
- **Where Neptune is differentiated:** it's a **fully-managed** AWS service (Multi-AZ HA,
  read replicas, serverless autoscaling, PITR backups, deep AWS integration) and adds
  **Gremlin**.
- **Where Fluree is differentiated on deployment:** it's **open-source / self-hostable**
  *and* ships its own AWS **serverless** offering (Fluree Serverless / "Solo":
  scale-to-zero, Lambda-backed, per-customer-isolated) plus a managed multi-tenant
  cloud — so it spans self-host, managed cloud, and AWS-serverless, not just one.
- **The decision axis is usually architectural, not query-language:** a proprietary
  AWS-only managed service (Neptune) vs an open-source immutable semantic ledger with
  reasoning, governance, and verifiability built in, deployable self-hosted / managed /
  serverless (Fluree).

---

## Feature matrix

Legend: ✅ native / supported · 🟡 partial or via add-on · ⟂ divergent by design · ❌ not supported

### RDF & SPARQL standards

| Capability | Fluree | Amazon Neptune |
|---|---|---|
| SPARQL 1.1 Query | ✅ ~78% W3C eval suite (256/327) | ✅ Fully compliant |
| SPARQL 1.1 Update | ✅ INSERT/DELETE (DATA + templated) | ✅ Full |
| SPARQL Federation (`SERVICE`) | 🟡 Fluree→Fluree (`fluree:remote:…`) | ✅ Standard `SERVICE`, **VPC-only** endpoints |
| Property paths | 🟡 `/ \| ^ + *` (no `?`, no `!p` neg. sets) | ✅ Full |
| Named graphs / `FROM` / `GRAPH` | ✅ Full datasets | ✅ — but default graph = **union of all** named graphs |
| RDF 1.2 reification / edge annotations | ✅ Triple terms via `rdf:reifies`, reifier `~`, annotation `{\| \|}` | ❌ None |
| Legacy RDF-star quoted-triple terms (`<< >>` as a term) | ⟂ Not implemented — superseded by the RDF 1.2 model above | ❌ |

### Serialization formats

| Format | Fluree | Neptune |
|---|---|---|
| Turtle / N-Triples / N-Quads | ✅ | ✅ |
| TriG | ✅ | ❌ |
| JSON-LD | ✅ (native query + load) | ❌ (not a bulk-load format) |
| RDF/XML | ❌ | ✅ |

### Semantics, governance & advanced features

| Capability | Fluree | Amazon Neptune |
|---|---|---|
| Reasoning / inference | ✅ RDFS, OWL 2 QL, OWL 2 RL, Datalog (per-ledger / per-query) | ❌ No native inferencing — requires external **RDFox** integration |
| SHACL validation | ✅ Native, at transaction time (reject/warn) | ❌ No native API (3rd-party, e.g. metaphactory) |
| Time-travel / as-of queries | ✅ Query any past state (`@t:` / `@iso:` / `@commit:`) | ❌ No queryable history; PITR **restore** only (operational) |
| Immutability / versioning | ✅ Content-addressed commits, git-like branch/merge | ❌ Mutable store; managed snapshots/backups |
| Fine-grained access control | ✅ **Triple-level** policy (`f:view`/`f:modify`) | 🟡 Coarse IAM action-level (`neptune-db:*`); no row/triple policy |
| Cryptographic verifiability | ✅ Ed25519-signed commits, JWS / Verifiable Credentials | ❌ |
| Vector search | ✅ Native HNSW (`@vector`, cosine/dot) | 🟡 Not in Neptune **Database**; only in separate **Neptune Analytics** engine |
| Full-text search | ✅ Native BM25 (Tantivy), time-travel aware | 🟡 Via **Amazon OpenSearch** integration (separate managed service) |
| openCypher | ✅ Broad openCypher-9 (read+write): `MATCH`/`OPTIONAL`/`WITH`/`UNWIND`/`CALL{}`/`CREATE`/`MERGE`/`SET`/`DELETE`, var-length + `shortestPath`. Deferred: `FOREACH`, `CALL proc`, `LOAD CSV` | ✅ Native, same store |
| Property graph via Gremlin | ❌ | ✅ Native, same store |
| ACID transactions | ✅ | ✅ |

### Operational & deployment

| | Fluree | Amazon Neptune |
|---|---|---|
| Deployment | Self-host / embeddable **+ managed cloud (data.flur.ee) + AWS Serverless** ("Solo") | **Managed AWS only** (no self-host) |
| License | Open source (**BUSL-1.1**) | Proprietary managed service |
| Storage backends | Memory, File, **S3**, DynamoDB (nameservice), IPFS | Managed Neptune cluster volume (decoupled compute/storage) |
| Serverless / scale-to-zero | ✅ **Fluree Serverless** (Lambda-backed, scale-to-zero, per-customer isolation) | ✅ **Neptune Serverless** (NCU autoscaling; min capacity, not to zero) |
| HA / replicas / autoscale | ✅ via Serverless; self-managed for self-host | ✅ Multi-AZ, read replicas, autoscaling |
| Bulk load path | CLI import / HTTP; `.flpack`, Turtle/JSON-LD | **S3 bulk loader** (Turtle/N-Triples/N-Quads/RDF-XML) |
| API surface | HTTP query/update/insert/upsert, JSON-LD, SPARQL, Cypher, multi-query, streaming NDJSON | SPARQL 1.1 + Gremlin + openCypher endpoints (`:8182`) |
| Result formats | JSON-LD, SPARQL-JSON, TSV/CSV, NDJSON | SPARQL-JSON/XML, CSV/TSV |

---

## The big differentiators, in plain terms

**Reasoning.** This is the sharpest RDF-specific gap. Neptune stores the RDFS/OWL
*vocabulary* and predefines the `rdfs:`/`owl:` prefixes, but its engine performs **no
inference** — `rdfs:subClassOf`, `owl:sameAs`, transitive/inverse properties, etc. are
not materialized or rewritten unless you bolt on a third-party reasoner (AWS's own
guidance is to integrate RDFox). Fluree ships RDFS, OWL 2 QL (query rewriting), OWL 2 RL
(materialization), and Datalog rules in-engine, toggleable per-ledger or per-query.

**Time & immutability.** Fluree's model *is* an immutable, content-addressed commit
chain — every transaction is a new version and you can query the graph **as of** any
past `t`, ISO time, or commit. Neptune is a conventional mutable store; its history
story is operational (Point-in-Time Recovery restores a *new* cluster), not a queryable
`as-of`. For audit, provenance, regulatory, and "what did we know on date X" workloads
this is a categorical difference.

**Governance.** Fluree enforces access control at the **flake (triple) level** with
`f:view`/`f:modify` policies, plus cryptographically-signed commits and Verifiable
Credentials. Neptune's authorization is IAM at the action level
(`neptune-db:ReadDataViaQuery`, etc.) — there's no built-in row/triple-level filtering
or commit signing.

**Multi-model & deployment.** Both query one store through multiple paradigms: Neptune
as RDF/SPARQL + property graph (Gremlin + openCypher), Fluree as RDF/SPARQL + JSON-LD +
openCypher. The genuine query-language gap is **Gremlin**, which Neptune has and Fluree
doesn't. On deployment the asymmetry runs the other way: Neptune is **AWS-managed only**,
while Fluree spans **self-host (open source), managed cloud, and AWS Serverless**
("Solo" — Lambda-backed, scale-to-zero, per-customer isolation). So each has a
serverless-on-AWS story; the difference is that Fluree also runs anywhere else and is
open source, whereas Neptune is a turnkey managed service with deeper native AWS
integration.

**RDF 1.2 & formats.** Fluree implements the **RDF 1.2** reification model — triple terms
via `rdf:reifies`, the `~` reifier, and `{| |}` edge annotations — which is also how its
openCypher relationships carry identity. **Neptune supports none of RDF 1.2** (nor legacy
RDF-star quoted triples). On serializations each has one the other lacks: Neptune loads
RDF/XML (Fluree doesn't); Fluree loads/queries JSON-LD natively and parses TriG (Neptune
doesn't).

---

## Performance: measured results

**DBLP-core (561.5 M triples) on matched AWS Graviton4 (`r8g`) instances at four sizes** —
Fluree v4.1.0 (native) on EC2 `r8g.*`, Neptune 1.4.7.0 on `db.r8g.*`, same silicon, only the
size changes. 105-query SPARQLoscope suite, 1 warmup + median of 3, 180 s budget, result cache
off. Run 2026-06-26. Full data + methodology:
[`reports/fluree-vs-neptune-scaling/`](benchmarks/sparqloscope/reports/fluree-vs-neptune-scaling/REPORT.md).

### Load

| Instance | Fluree load | Fluree tr/s | Neptune load | Neptune tr/s |
|---|---|---|---|---|
| 4c/32 GB | **861 s** | 652 K/s | 13,086 s | 43 K/s |
| 8c/64 GB | **711 s** | 790 K/s | 6,259 s | 90 K/s |
| 16c/128 GB | **449 s** | 1.25 M/s | 3,893 s | 144 K/s |
| 32c/256 GB | **421 s** | **1.33 M/s** | resized in-place ¹ | — |

Fluree loads **9–15× faster at every size** (peaking at 1.33 M triples/s, flattening past 16
cores as it goes I/O-bound). And Neptune **can't ingest DBLP-core as-is**: its bulk loader
rejects blank nodes (~42 % of the triples), failing 1:1 with `Expected '<', found: _`. We
skolemized `_:label`→IRI (as the repo's Blazegraph run did) so Neptune could load at all —
preprocessing Fluree never needed. ¹ The 256 GB Neptune cluster was resized from the 128 GB
one in place (data preserved), so its load wasn't re-measured.

### Query suite (105 queries, 180 s budget, warm)

| Instance | Fluree | Neptune | Neptune geomean (passed) | Neptune P=2 geomean |
|---|---|---|---|---|
| 4c/32 GB | **105/105 · 26.7 ms** | 16/105 | 9,895 ms | 208,187 ms |
| 8c/64 GB | **105/105 · 21.7 ms** | 10/105 | 15,133 ms | 266,207 ms |
| 16c/128 GB | **105/105 · 18.0 ms** | 81/105 | 6,536 ms | 16,341 ms |
| 32c/256 GB | **105/105 · 16.6 ms** | 84/105 | 7,587 ms | 16,417 ms |

**Fluree passes all 105 at every size** (geomean numbers are passed-only = P=2 since it never
fails). **Neptune is non-functional below 128 GB** (10–16/105 — mostly OOM/timeout), **crosses
over at 128 GB (81/105)**, then **plateaus** (256 GB adds just +3 → 84/105). A core group
(`exists-join-3-*`, `exists-join-2-large-large-with-large-result`, …) **times out at every
size**.

**The key scaling finding — RAM buys *completion*, not *speed*:** queries Neptune completes run
at essentially the **same latency regardless of box size** (`date-day` ≈ 18 s at 32, 64, 128 and
256 GB); extra RAM only converts OOM/timeout → completion. Even at its best (256 GB, 84/105),
Neptune's geomean is **7,587 ms vs Fluree's 16.6 ms — ~460×**. (The 64 GB dip to 10/105,
*below* 32 GB's 16, is real and reproduced: the 2xlarge gives more memory per query thread, so
several heavy queries OOM where the smaller box merely runs them slowly.)

---

## How it was run

**Why `r8g` and why scale it.** Neptune can only be provisioned on **memory-optimized R/X**
(8:1 GB/vCPU) or burstable **T** families — there is **no general-purpose (M) family**, so it
can't run on the `m7a.4xlarge` (4:1) the 7-engine suite used. So we put both engines on
Neptune's *own* preferred family, **Graviton4 `r8g`** (8:1), and — rather than pick one size —
**scaled it across four sizes (32/64/128/256 GB)** to find where, if anywhere, Neptune becomes
competitive. Same silicon throughout; only the size changes. Fluree (open-source) runs on an
EC2 `r8g.*`; Neptune runs on `db.r8g.*` and is queried from an in-VPC client (a cheap
`t4g.medium` suffices — the client only issues `curl`, all query work is server-side).

### Methodology specifics (Neptune is managed)

1. **Query-timeout parity.** Neptune's default `neptune_query_timeout` is **120 s** < the
   suite's 180 s; we raised it to **180000** (custom cluster parameter group) so Neptune gets
   the same budget as every other engine. A param-group change forces a reboot that cold-wipes
   the buffer pool, so on fresh clusters we set it *before* loading (warm bench); the one
   cluster where we set it after loading produced a cold-cascade and was re-run warm.
2. **Blank nodes / skolemization.** Neptune's bulk loader **rejects N-Triples blank nodes**
   (confirmed 1:1 — every `_:` line → one parse error), and DBLP-core is ~42 % blank-node
   triples. We skolemized `_:label`→IRI (saved once in S3, reused for all loads) so Neptune
   could load at all. Fluree loaded the raw file natively. This is a Neptune capability gap.
3. **Load path & reachability.** Neptune ingests via the **S3 bulk loader**; its SPARQL
   endpoint is **VPC-only** (driven from the in-VPC client). The 256 GB cluster was resized
   in-place from 128 GB (data preserved, no reload).
4. **Small-box instability.** On a 32 GB box (~21 GB buffer pool < dataset) Neptune's
   pass-count is genuinely **cache-sensitive (9–48 across runs)**; reported as 16/105 with that
   caveat. 128 GB and up are stable.

Not bit-comparable to the same-box `dblp-core` run (different hardware family, engine versions,
and skolemized Neptune input). Full per-tier data, raw TSVs, and `meta.json` live in
[`benchmarks/sparqloscope/reports/fluree-vs-neptune-scaling/`](benchmarks/sparqloscope/reports/fluree-vs-neptune-scaling/REPORT.md).

---

## Sources

- [Choosing instance types for Amazon Neptune](https://docs.aws.amazon.com/neptune/latest/userguide/instance-types.html)
- [SPARQL standards compliance in Amazon Neptune](https://docs.aws.amazon.com/neptune/latest/userguide/feature-sparql-compliance.html)
- [RDF load data formats (Neptune bulk loader)](https://docs.aws.amazon.com/neptune/latest/userguide/bulk-load-tutorial-format-rdf.html)
- [SPARQL federated queries (SERVICE) in Neptune](https://docs.aws.amazon.com/neptune/latest/userguide/sparql-service.html)
- [Full-text search in Neptune using OpenSearch](https://docs.aws.amazon.com/neptune/latest/userguide/full-text-search.html)
- [Use semantic reasoning by integrating RDFox with Neptune (AWS blog)](https://aws.amazon.com/blogs/database/use-semantic-reasoning-to-infer-new-facts-from-your-rdf-graph-by-integrating-rdfox-with-amazon-neptune/)
- Fluree feature evidence: `docs/` tree (sparql, reasoning, time-travel, policy,
  vector-search, bm25, cypher-support-matrix) and crate sources (`fluree-db-sparql`,
  `fluree-db-reasoner`, `fluree-db-shacl`, `fluree-db-policy`, `fluree-search-service`).
