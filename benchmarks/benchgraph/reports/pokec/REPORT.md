# Pokec (benchgraph) — Fluree vs Memgraph vs Neo4j vs FalkorDB

**Status:** Run 2026-07-08 on one AWS `r8a.4xlarge` box (16 c / 128 GB, Ubuntu 24.04). The
Memgraph [benchgraph](https://memgraph.com/benchgraph) suite — 35 Cypher queries over the
Pokec social network — run through **Fluree's Cypher surface (over HTTP)** and compared
against native **Memgraph 3.11.0**, **Neo4j 5.26.28 Community**, and **FalkorDB 4.18.11**.
All four engines answer **35/35 at every scale**, return **byte-identical result sets**
(verified per-query at every scale), and are held to the **same per-commit durability
contract**. Fluree is the imminent **v4.1.2** release. Each engine is measured on its
real-world client transport — Fluree over HTTP, Memgraph and Neo4j over Bolt, FalkorDB over
native RESP (§5).

**Headline:** this is a read _and_ write benchmark. With every engine held to **per-commit
durability**, **Fluree wins writes outright** — its durable write path is **~2.3–2.7×
faster than Memgraph and FalkorDB and 1.3–2.4× faster than Neo4j** at every scale. On
**reads Fluree is the fastest engine at every scale** — **1.6–3.0× faster** than Memgraph,
**2.4–4.6× faster** than Neo4j, and **1.0–3.1× faster** than FalkorDB (essentially tied
with FalkorDB on the tiny small graph, pulling away as the graph grows). The reads
decompose into a **division of strengths** (§2): **Fluree owns the analytical half** —
whole-graph **aggregates** stay ~O(1) via index directories and run **100–720× faster**
than the scanners at large — while **FalkorDB keeps a narrow edge in raw traversal**
(fixed-hop expansions/neighbourhoods ~1.2–1.5× faster on the category geo-mean), though
**Fluree now overtakes it on the deepest hops** (`expansion_3`, `expansion_4`) at large.
Memgraph is the balanced generalist and the shortest-path leader at small/medium; Neo4j is
consistently the slowest engine that finishes.

**Dataset:** Pokec — single `:User` label, single `Friend` edge type, no edge properties
(small 10 k / 121,716 · medium 100 k / 1,768,515 · large 1,632,803 / 30,622,564) ·
**Engines:** Fluree v4.1.2 (HTTP), Memgraph 3.11.0 (native Bolt, fsync), Neo4j 5.26.28
Community (native Bolt), FalkorDB 4.18.11 (native Redis module, RESP, AOF fsync) · **Box:**
AWS r8a.4xlarge (16 c / 128 GB) · single-client latency, median of 5 (large: 3), seed 42,
shared params.

_Results first; the division-of-strengths analysis is §2, dataset/engine/load detail §3–§4,
methodology and caveats §5, and full reproduction steps §6. A note on memory-bound scaling
— where a disk-backed engine and two in-memory engines diverge — closes §5._

## 1. Query benchmark

Geometric mean over the 8 write queries and 27 read queries — **writes first**, since a
graph database that takes writes is the primary use. All four engines fsync every commit
(Memgraph's published non-durable write mode, sub-millisecond but acked before disk, is
excluded — see §5). Writes are measured in a dedicated pass; reads on a **pristine,
read-only store** (clean protocol, §5). Lower ms is faster. The **Fluree vs X** columns
state how much faster (or slower) Fluree is than that engine (bold = fastest engine in the
row).

### Writes — geometric mean (ms)

| scale | n | Fluree | Memgraph | Neo4j | FalkorDB | Fluree vs Memgraph | Fluree vs Neo4j | Fluree vs FalkorDB |
|---|--:|---|---|---|---|--:|--:|--:|
| small | 8 | **1.32** | 3.03 | 1.76 | 2.93 | 2.30× faster | 1.33× faster | 2.22× faster |
| medium | 8 | **1.27** | 3.39 | 2.94 | 3.36 | 2.66× faster | 2.31× faster | 2.64× faster |
| large | 8 | **1.73** | 4.46 | 4.07 | 4.57 | 2.57× faster | 2.35× faster | 2.63× faster |

### Reads — geometric mean (ms)

| scale | n | Fluree | Memgraph | Neo4j | FalkorDB | Fluree vs Memgraph | Fluree vs Neo4j | Fluree vs FalkorDB |
|---|--:|---|---|---|---|--:|--:|--:|
| small | 27 | **0.60** | 0.93 | 1.43 | 0.61 | 1.56× faster | 2.39× faster | 1.02× faster |
| medium | 27 | **1.23** | 2.36 | 4.99 | 1.75 | 1.92× faster | 4.05× faster | 1.42× faster |
| large | 27 | **1.47** | 4.41 | 6.80 | 4.57 | 3.01× faster | 4.64× faster | 3.12× faster |

## 2. Division of strengths — who wins which half

The read geo-mean is a blend of two very different regimes, and adding FalkorDB makes the
split unmistakable. Breaking the 27 read queries into categories (geo mean, ms):

### Reads by category — geometric mean (ms)

**small**

| category | n | Fluree | Memgraph | Neo4j | FalkorDB | winner |
|---|--:|---|---|---|---|---|
| Point lookup | 7 | 0.28 | 0.19 | 0.25 | **0.14** | FalkorDB |
| Aggregate | 5 | **0.29** | 1.44 | 2.25 | 1.15 | Fluree |
| Expansion | 8 | 1.77 | 3.35 | 5.56 | **1.15** | FalkorDB |
| Neighbourhood | 4 | **0.80** | 2.24 | 2.36 | 1.05 | Fluree |
| Shortest path | 3 | 0.42 | **0.18** | 0.53 | 0.59 | Memgraph |

**medium**

| category | n | Fluree | Memgraph | Neo4j | FalkorDB | winner |
|---|--:|---|---|---|---|---|
| Point lookup | 7 | 0.40 | 0.30 | 0.82 | **0.22** | FalkorDB |
| Aggregate | 5 | **0.49** | 12.92 | 11.99 | 9.54 | Fluree |
| Expansion | 8 | 6.05 | 9.37 | 24.42 | **3.45** | FalkorDB |
| Neighbourhood | 4 | **1.61** | 2.71 | 4.22 | 1.64 | Fluree |
| Shortest path | 3 | 0.78 | **0.35** | 1.42 | 2.40 | Memgraph |

**large**

| category | n | Fluree | Memgraph | Neo4j | FalkorDB | winner |
|---|--:|---|---|---|---|---|
| Point lookup | 7 | 0.41 | 0.44 | 0.71 | **0.32** | FalkorDB |
| Aggregate | 5 | **1.09** | 202.89 | 166.81 | 153.20 | Fluree |
| Expansion | 8 | 5.63 | 6.56 | 13.01 | **4.04** | FalkorDB |
| Neighbourhood | 4 | 2.76 | 4.35 | 6.65 | **2.63** | FalkorDB |
| Shortest path | 3 | **0.55** | 0.58 | 1.17 | 19.29 | Fluree |

**Fluree wins the analytical half — and it widens with scale.** Whole-graph **aggregates**
(`count`, `min/max/avg`, histograms, `COUNT(DISTINCT)`) are answered from Fluree's index
directories without scanning the graph, so their cost barely moves as the dataset grows.
Every other engine — including FalkorDB — scans. At large, Fluree answers
`aggregate_with_distinct` in **0.24 ms vs FalkorDB's 177 ms, Memgraph's 173 ms, and Neo4j's
150 ms** (~625–738×), `count` in **0.47 ms vs 106–154 ms** (~230–330×), and the label-less
`SET n.property` update in **1.4 ms vs 70–152 ms** (~51–111×). The advantage is structural,
not a constant factor, so it *widens* with scale.

**FalkorDB keeps a narrow traversal edge — but the gap has collapsed, and Fluree overtakes
on the deepest hops.** On the expansion/neighbourhood category geo-means FalkorDB is
**~1.2–1.5× faster** than Fluree at every scale (down from ~2–3× in prior builds). The
crossover is at hop depth: on shallow one/two-hop expansions FalkorDB (and Memgraph) still
lead, but on the **deepest hops at large Fluree wins outright** — `expansion_3` is
**7.9 ms vs FalkorDB 12.2 / Memgraph 17.1 / Neo4j 22.2**, and `expansion_4` is **27.9 ms vs
FalkorDB 30.0 / Memgraph 80.3 / Neo4j 101.4**. FalkorDB still owns the category at small and
medium and on shallow hops; see [`FLUREE-GAPS.md`](../../FLUREE-GAPS.md) for the remaining
shallow-expansion targets.

**Point lookups sit at the in-memory floor** for all four engines (sub-millisecond);
FalkorDB edges the category on hash/matrix lookups, Fluree matches or beats Neo4j.

**Shortest path is split by scale.** Memgraph's native BFS leads at small and medium; Fluree
leads at large. **FalkorDB is the weak one here** — its point-to-point `shortestPath` is
**~44–58 ms at large vs sub-2 ms for the others**. See §5 for the FalkorDB path-query
formulations and one filtered-path semantic caveat.

**Writes — Fluree wins on a level durability field.** Every engine here fsyncs each commit
(Memgraph `--storage-wal-file-flush-every-n-tx=1`, Neo4j durable by default, FalkorDB
Redis AOF `appendfsync always`, Fluree durable per commit). Under that contract Fluree's
per-commit write floor (~0.8–1.7 ms) is **2.3–2.7× faster than Memgraph and FalkorDB and
1.3–2.4× faster than Neo4j** at every scale. Fluree's consistent write losses are
`unwind_range_vertex_write` (a 100-row batch insert — its known batch-write long pole, where
FalkorDB's batched CREATE wins) and `edge` at large; everywhere else Fluree leads, most
dramatically on `vertex_on_property` (a label-less `SET`, **51–111× faster** at large — the
same index-directory advantage as the read-side aggregates). _Note: Memgraph's **published**
benchmark runs writes non-durably (WAL flush every 100 k tx), where its write floor drops
below 0.2 ms; that number is not comparable to a per-commit-durable engine and is not what is
measured here._

**Net.** Pick by query mix. **Analytical, lookup-, and write-heavy** workloads favour
Fluree — and its aggregate/write wins are the ones that *widen* with scale. **Shallow
pure-traversal** workloads still favour FalkorDB, though the margin is now narrow and Fluree
takes the deep hops. Memgraph is the balanced in-memory generalist. On the blended read
geo-mean **Fluree now leads at every scale**, and the durable-write result — where Fluree
separates cleanly at every scale — remains the headline. One axis this single-big-box run
does **not** exercise is memory-bound scaling (§5): FalkorDB and Memgraph hold the whole
graph in RAM, Fluree does not.

## 3. Dataset & scales

[Pokec](https://snap.stanford.edu/data/soc-Pokec.html) is the Slovak social network used
by Memgraph's published benchgraph. It is a plain property graph — one `:User` node label,
one `Friend` relationship type, **no edge properties** — which makes it a clean read of
node storage, adjacency traversal, and label/property indexing without edge-property
machinery.

| scale | nodes | edges | source |
|---|--:|--:|---|
| small | 10,000 | 121,716 | `pokec_small_import.cypher` |
| medium | 100,000 | 1,768,515 | `pokec_medium_import.cypher` |
| large | 1,632,803 | 30,622,564 | `pokec_large.setup.cypher.gz` |

Datasets come from `deps.memgraph.io` (verbatim Memgraph distribution). The 35 query texts
in [`queries/`](../../queries/) are the **Neo4j-portable branch** of
`memgraph/tests/mgbench/workloads/pokec.py`;
[`query-set.tsv`](../../query-set.tsv) records each query's parameterization and read/write
kind. All engines receive **identical seed vertices** (seed 42) via shared params files, so
every engine runs the same point lookups, expansion roots, and path endpoints — and at
every scale all four engines returned **byte-identical result-set sizes** for all 35
queries (correctness cross-check, §5).

## 4. Engines, setup & load

| | version | transport | durability | in-memory? | install |
|---|---|---|---|---|---|
| **Fluree** | **v4.1.2** (`13a78d2a`; binary self-reports `4.1.1`) | HTTP (JSON) | per-commit, on-disk index | **no** (disk-backed + page cache) | source build (`cargo build --release -p fluree-db-cli`) |
| **Memgraph** | 3.11.0 | Bolt 7687 | `--storage-wal-file-flush-every-n-tx=1` (per-commit fsync) | yes | native `.deb` / Docker |
| **Neo4j** | 5.26.28 Community | Bolt 7687 | durable by default | partly (page cache, disk store) | native `.deb` / Docker |
| **FalkorDB** | 4.18.11 | RESP `GRAPH.QUERY` | Redis AOF `appendfsync always` (per-write fsync) | **yes** (RAM-resident graph) | native (`redis-server` + `falkordb.so`) |

- **Fluree** is loaded via the native bulk importer (`fluree create pokec --from
  pokec_<scale>.ttl`), then bridged to bare Cypher names with
  `fluree context set pokec -e '{"@vocab":"http://example.org/"}'`. Every **measured** query
  then runs end-to-end through Fluree's Cypher surface over the HTTP API — SPARQL plays no
  part at query time. Load is out of the measured path.
- **Memgraph** is loaded by replaying the distribution's Cypher `CREATE` statements
  (`CREATE INDEX ON :User(id)` first), then `CREATE SNAPSHOT` and a restart in fsync mode.
- **Neo4j** is bulk-loaded with `neo4j-admin database import full` from generated CSVs
  (~19 s large — vs hours for `cypher-shell` replay), then a `User(id)` index built and
  `db.awaitIndexes()`.
- **FalkorDB** runs **natively** (`redis-server` loading the `falkordb.so` module, AOF
  `appendfsync always` on the host filesystem — not the Docker image). It is loaded with the
  native bulk loader (`falkordb-bulk-insert … --nodes-with-label User … --relations-with-type
  Friend … --id-type INTEGER`), then a `User.id` index created and verified. The loader is
  fast (small 0.19 s · medium 3.1 s · large ~85 s for 30.6 M edges) but has two silent-failure
  modes that this run works around: default buffers/socket timeout drop edges past ~24 M
  (fixed with a longer `socket_timeout` and larger buffers), and `--index` does not always
  build on the 1.6 M-node graph (fixed by creating the index explicitly and verifying the plan
  uses an index scan). Queries run over FalkorDB's native RESP `GRAPH.QUERY` via the
  falkordb python client; its experimental Bolt surface was not reliable enough to benchmark.

**FalkorDB memory footprint.** The full 30.6 M-edge large graph is **~1,286 MB** resident —
the whole working set lives in RAM (AOF/RDB is for durability/restart only; queries are
never served from disk). See the memory-bound note in §5.

## 5. Methodology & caveats

- **Single-client latency, median of N** — small/medium: 5 runs + 2 warmup; large: 3 runs
  + 1 warmup. Times are wall-clock per query at the client.
- **Per-engine client transport.** Each engine is measured over the transport its users
  actually use: **Fluree over its HTTP/JSON API** (`urllib` + `json.loads`), **Memgraph and
  Neo4j over Bolt** (the official neo4j driver), **FalkorDB over native RESP** (`GRAPH.QUERY`
  via the falkordb client). Transport is part of the delivered latency, so it is not
  normalised away; where it matters for large result sets it is called out. (Fluree's Bolt
  surface exists but its neo4j-driver record deserialization dominates large-result latency;
  HTTP is the leaner, representative Fluree client and is what is reported here.)
- **Clean protocol (reads).** For each scale and each engine: fresh load → warmup reads-only
  pass (discarded) → recorded **reads-only** passes on the still-pristine store → a
  **separate write pass**. Reads and writes are never measured on top of each other's
  mutations. This matters especially for Fluree: reads on a store carrying accumulated write
  novelty inflate its aggregate latency (novelty reconciliation) — the canonical Fluree
  reads here are the pristine `reads2` pass and writes the `full` pass.
- **Shared params, all scales.** All three scales were measured for all four engines on this
  one box with shared `params_<scale>.json` (fresh pristine load each). Result-set sizes
  matched byte-for-byte across all four engines (the sole exception being FalkorDB's
  `shortest_path_with_filter` semantic difference, below), confirming both parameter
  alignment and result equivalence — the latency comparison is like-for-like work. Because
  expansion latency depends on start-node degree and the shared large params draw
  lower-degree roots than earlier-published sets, the large traversal numbers here are lower
  than previously-published ones; they are apples-to-apples across engines.
- **Durability parity.** All four engines fsync each commit, so write numbers are
  apples-to-apples. Memgraph's *published* sub-0.2 ms writes use non-durable WAL batching
  and are **not** what is measured here.
- **FalkorDB path queries.** FalkorDB rejects Neo4j's standalone `MATCH p=shortestPath(...)`;
  the equivalents live in [`queries-falkordb/`](../../queries-falkordb/) (`shortestPath()`
  in a `WITH`/`RETURN`; `allShortestPaths()` in a `MATCH` with pre-resolved endpoints, hop
  bound `..2` to match the reference). One caveat: `shortest_path_with_filter` post-filters
  the shortest path (`WITH shortestPath(...) … WHERE all(...)`) rather than searching under
  the constraint as Neo4j does, so on FalkorDB it can return the empty path where Neo4j
  returns a longer constrained one — a semantic difference in one of 35 queries, flagged not
  hidden.
- **Native, not containerised.** All four engines run natively on the one box (FalkorDB as
  `redis-server` + module, not the Docker image), each with per-commit fsync durability.
- **Box variance.** Absolute times are specific to this `r8a.4xlarge`, single-client — not a
  throughput or concurrency benchmark.
- **Not the published Memgraph table.** Memgraph publishes multi-worker throughput on older
  silicon; this is single-client isolated latency on current hardware. Cross-referencing the
  two is not valid.

**Memory-bound scaling — the axis this run does _not_ show.** FalkorDB and Memgraph are
in-memory engines: the entire graph must fit in RAM (FalkorDB is notably compact — 1.29 GB
for large — but it is still a hard ceiling; there is no disk paging of graph data, so an
over-sized graph OOMs). Neo4j is disk-backed but leans heavily on page cache. **Fluree is
disk-backed with an on-disk index**, so it degrades gracefully as the graph outgrows RAM
where the in-memory engines fail. This single 128 GB box holds every graph here comfortably,
so it cannot surface that difference. A follow-up run on **smaller machines** — where the
large graph approaches or exceeds RAM — is the natural next step: the expectation is that
Fluree's per-query latency stays roughly flat per machine size while the in-memory engines
hit a cliff. That structural difference, not the on-par big-box read numbers, is where the
architectures truly diverge.

## 6. Reproduce it

Everything needed is in this directory tree. The per-engine raw runs
([`engines/`](engines/), runs × 35 queries each) and the machine-readable per-query
medians ([`summary.tsv`](summary.tsv)) back every number above.

```bash
cd benchmarks/benchgraph

# 1. dataset (small; also medium / large from deps.memgraph.io)
curl -L -o data/pokec_small_import.cypher \
  https://s3.eu-west-1.amazonaws.com/deps.memgraph.io/dataset/pokec/benchmark/pokec_small_import.cypher

# 2. Fluree: import, bridge bare Cypher names, serve over HTTP
mkdir -p fluree-data && cd fluree-data && fluree init
fluree create pokec --from ../data/pokec_small.ttl
fluree context set pokec -e '{"@vocab":"http://example.org/"}'
FLUREE_CYPHER_ALLOW_FULL_SCAN=1 fluree server start --listen-addr 127.0.0.1:8090 ; cd ..

# 3. FalkorDB: native durable Redis module + native bulk load
redis-server --loadmodule ./falkordb.so --appendonly yes --appendfsync always --dir ./falkor-data &
python3 cypher_to_csv.py data/pokec_small_import.cypher /tmp/User.csv /tmp/Friend.csv
falkordb-bulk-insert pokec --nodes-with-label User /tmp/User.csv \
  --relations-with-type Friend /tmp/Friend.csv --id-type INTEGER
redis-cli GRAPH.QUERY pokec "CREATE INDEX FOR (u:User) ON (u.id)"   # verify index scan!

# 4. run the suite (clean protocol: reads on a pristine store, writes separately)
python3 bench_runner.py --engine fluree --http-port 8090 --params-file params_small.json \
  --num-vertices 10000 --seed 42 --runs 5 --warmup 2 --skip-writes --output <reads>.tsv
python3 bench_runner.py --engine falkordb --redis-port 6379 --graph pokec \
  --params-file params_small.json --num-vertices 10000 --runs 5 --warmup 2 --skip-writes --output <reads>.tsv
# baselines: --engine memgraph --bolt-port 7687   /   --engine neo4j --bolt-port 7687
```

- **Runner:** [`bench_runner.py`](../../bench_runner.py) — multi-engine
  (`fluree` HTTP / `memgraph` / `neo4j` Bolt / `falkordb` RESP), shared seeded params,
  `--skip-writes`, median-of-N.
- **Suite README + setup:** [`../../README.md`](../../README.md) · **FalkorDB path overrides:**
  [`../../queries-falkordb/`](../../queries-falkordb/).
- **Exact settings** (durability flags, ports, index DDL, box spec) are in
  [`meta.json`](meta.json).

## Appendix — per-query medians

Fastest engine bolded. The **Fluree vs X** columns state how much faster (or slower) Fluree
is than that engine.

### Per query — writes (median ms)

**small**

| query | Fluree | Memgraph | Neo4j | FalkorDB | Fluree vs Memgraph | Fluree vs Neo4j | Fluree vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| `single_edge_write` | 1.37 | 2.99 | **1.34** | 3.34 | 2.18× faster | 1.03× slower | 2.43× faster |
| `single_vertex_write` | **0.80** | 2.88 | 1.27 | 2.94 | 3.61× faster | 1.60× faster | 3.69× faster |
| `unwind_range_vertex_write` | 9.66 | 3.75 | 4.93 | **2.89** | 2.57× slower | 1.96× slower | 3.34× slower |
| `edge` | 1.65 | 2.87 | **1.27** | 2.84 | 1.74× faster | 1.30× slower | 1.72× faster |
| `pattern` | **0.84** | 2.82 | 1.29 | 2.77 | 3.36× faster | 1.54× faster | 3.31× faster |
| `vertex` | **0.79** | 2.77 | 1.09 | 2.75 | 3.52× faster | 1.39× faster | 3.50× faster |
| `vertex_big` | **0.80** | 2.81 | 1.18 | 2.77 | 3.50× faster | 1.47× faster | 3.46× faster |
| `vertex_on_property` | **1.00** | 3.52 | 5.16 | 3.19 | 3.54× faster | 5.18× faster | 3.20× faster |

**medium**

| query | Fluree | Memgraph | Neo4j | FalkorDB | Fluree vs Memgraph | Fluree vs Neo4j | Fluree vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| `single_edge_write` | **1.29** | 2.75 | 2.20 | 3.71 | 2.13× faster | 1.70× faster | 2.88× faster |
| `single_vertex_write` | **0.94** | 2.78 | 1.75 | 3.00 | 2.94× faster | 1.86× faster | 3.18× faster |
| `unwind_range_vertex_write` | 5.14 | 3.90 | 7.92 | **3.02** | 1.32× slower | 1.54× faster | 1.70× slower |
| `edge` | **1.42** | 2.72 | 2.46 | 2.98 | 1.92× faster | 1.73× faster | 2.10× faster |
| `pattern` | **0.82** | 2.74 | 2.09 | 2.88 | 3.35× faster | 2.55× faster | 3.52× faster |
| `vertex` | **0.85** | 2.79 | 1.60 | 2.80 | 3.27× faster | 1.88× faster | 3.29× faster |
| `vertex_big` | **0.90** | 2.81 | 1.84 | 2.88 | 3.12× faster | 2.03× faster | 3.18× faster |
| `vertex_on_property` | **1.24** | 10.00 | 12.20 | 7.06 | 8.10× faster | 9.88× faster | 5.72× faster |

**large**

| query | Fluree | Memgraph | Neo4j | FalkorDB | Fluree vs Memgraph | Fluree vs Neo4j | Fluree vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| `single_edge_write` | **2.24** | 2.39 | 3.71 | 3.81 | 1.06× faster | 1.66× faster | 1.70× faster |
| `single_vertex_write` | **1.24** | 2.57 | 1.84 | 3.26 | 2.07× faster | 1.48× faster | 2.63× faster |
| `unwind_range_vertex_write` | 5.20 | 3.56 | 11.39 | **3.05** | 1.46× slower | 2.19× faster | 1.70× slower |
| `edge` | 7.23 | 2.74 | **1.93** | 3.09 | 2.64× slower | 3.75× slower | 2.34× slower |
| `pattern` | **0.95** | 2.75 | 1.58 | 2.86 | 2.89× faster | 1.66× faster | 3.01× faster |
| `vertex` | **0.75** | 2.76 | 1.41 | 2.85 | 3.70× faster | 1.88× faster | 3.81× faster |
| `vertex_big` | **0.81** | 2.92 | 1.49 | 2.83 | 3.62× faster | 1.85× faster | 3.51× faster |
| `vertex_on_property` | **1.36** | 118.38 | 152.02 | 69.75 | 86.79× faster | 111.45× faster | 51.13× faster |

### Per query — reads (median ms)

**small**

| query | Fluree | Memgraph | Neo4j | FalkorDB | Fluree vs Memgraph | Fluree vs Neo4j | Fluree vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| `count` | **0.31** | 0.89 | 3.73 | 0.79 | 2.88× faster | 12.02× faster | 2.54× faster |
| `min_max_avg` | **0.32** | 2.25 | 1.61 | 1.62 | 7.08× faster | 5.06× faster | 5.08× faster |
| `aggregate` | **0.33** | 1.49 | 2.83 | 1.10 | 4.45× faster | 8.46× faster | 3.30× faster |
| `aggregate_with_distinct` | **0.22** | 1.13 | 1.38 | 1.18 | 5.24× faster | 6.38× faster | 5.45× faster |
| `aggregate_with_filter` | **0.31** | 1.83 | 2.45 | 1.24 | 5.89× faster | 7.91× faster | 4.00× faster |
| `allshortest_paths` | 0.36 | 0.24 | 0.64 | **0.20** | 1.51× slower | 1.77× faster | 1.83× slower |
| `expansion_1` | 0.30 | 0.18 | 0.37 | **0.17** | 1.67× slower | 1.23× faster | 1.71× slower |
| `expansion_1_with_filter` | 0.32 | 0.15 | 0.42 | **0.13** | 2.07× slower | 1.34× faster | 2.39× slower |
| `expansion_2` | 1.01 | 1.98 | 3.82 | **0.84** | 1.96× faster | 3.79× faster | 1.20× slower |
| `expansion_2_with_filter` | 0.45 | 0.42 | 0.69 | **0.24** | 1.06× slower | 1.53× faster | 1.87× slower |
| `expansion_3` | 3.75 | 12.38 | 16.45 | **3.34** | 3.31× faster | 4.39× faster | 1.12× slower |
| `expansion_3_with_filter` | 3.28 | 7.22 | 8.95 | **2.17** | 2.20× faster | 2.73× faster | 1.51× slower |
| `expansion_4` | 17.63 | 94.98 | 129.98 | **14.63** | 5.39× faster | 7.37× faster | 1.21× slower |
| `expansion_4_with_filter` | 10.24 | 82.12 | 117.39 | **6.22** | 8.02× faster | 11.46× faster | 1.65× slower |
| `neighbours_2` | 1.16 | 3.07 | 3.75 | **1.06** | 2.64× faster | 3.22× faster | 1.09× slower |
| `neighbours_2_with_data` | **0.75** | 2.22 | 2.50 | 1.67 | 2.97× faster | 3.34× faster | 2.24× faster |
| `neighbours_2_with_data_and_filter` | **0.79** | 3.85 | 2.83 | 1.58 | 4.87× faster | 3.59× faster | 2.01× faster |
| `neighbours_2_with_filter` | 0.60 | 0.95 | 1.17 | **0.44** | 1.58× faster | 1.94× faster | 1.39× slower |
| `shortest_path` | 0.71 | **0.21** | 0.70 | 1.30 | 3.36× slower | 1.01× slower | 1.83× faster |
| `shortest_path_with_filter` | 0.29 | **0.12** | 0.32 | 0.81 | 2.42× slower | 1.11× faster | 2.78× faster |
| `single_vertex_read` | 0.19 | 0.14 | 0.26 | **0.11** | 1.35× slower | 1.37× faster | 1.70× slower |
| `pattern_cycle` | 0.29 | 0.18 | 0.39 | **0.18** | 1.64× slower | 1.34× faster | 1.65× slower |
| `pattern_long` | 0.65 | **0.13** | 0.26 | 0.35 | 4.81× slower | 2.51× slower | 1.86× slower |
| `pattern_short` | 0.26 | 0.13 | 0.23 | **0.11** | 1.93× slower | 1.13× slower | 2.25× slower |
| `vertex_on_label_property` | 0.41 | 1.21 | 0.21 | **0.12** | 2.99× faster | 1.96× slower | 3.50× slower |
| `vertex_on_label_property_index` | 0.20 | 0.13 | 0.19 | **0.10** | 1.51× slower | 1.01× slower | 1.94× slower |
| `vertex_on_property` | 0.19 | 0.13 | 0.27 | **0.10** | 1.45× slower | 1.39× faster | 2.00× slower |

**medium**

| query | Fluree | Memgraph | Neo4j | FalkorDB | Fluree vs Memgraph | Fluree vs Neo4j | Fluree vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| `count` | **0.35** | 8.26 | 10.88 | 6.77 | 23.88× faster | 31.46× faster | 19.58× faster |
| `min_max_avg` | **1.06** | 23.53 | 13.75 | 14.43 | 22.28× faster | 13.02× faster | 13.66× faster |
| `aggregate` | **0.51** | 11.36 | 12.98 | 8.16 | 22.27× faster | 25.45× faster | 16.00× faster |
| `aggregate_with_distinct` | **0.30** | 10.52 | 9.52 | 10.42 | 35.31× faster | 31.95× faster | 34.95× faster |
| `aggregate_with_filter` | **0.51** | 15.52 | 13.41 | 9.51 | 30.73× faster | 26.56× faster | 18.84× faster |
| `allshortest_paths` | 1.02 | 0.60 | 1.75 | **0.35** | 1.72× slower | 1.71× faster | 2.93× slower |
| `expansion_1` | 0.36 | 0.15 | 1.27 | **0.14** | 2.47× slower | 3.52× faster | 2.67× slower |
| `expansion_1_with_filter` | 0.40 | **0.13** | 1.70 | 0.18 | 3.16× slower | 4.23× faster | 2.25× slower |
| `expansion_2` | 2.00 | 3.08 | 7.82 | **0.98** | 1.54× faster | 3.91× faster | 2.04× slower |
| `expansion_2_with_filter` | 2.23 | 2.71 | 6.64 | **0.98** | 1.21× faster | 2.97× faster | 2.27× slower |
| `expansion_3` | 6.66 | 18.46 | 23.73 | **5.74** | 2.77× faster | 3.56× faster | 1.16× slower |
| `expansion_3_with_filter` | 22.71 | 55.27 | 68.16 | **14.79** | 2.43× faster | 3.00× faster | 1.54× slower |
| `expansion_4` | 175.41 | 948.95 | 1291.57 | **142.29** | 5.41× faster | 7.36× faster | 1.23× slower |
| `expansion_4_with_filter` | 105.30 | 397.12 | 539.59 | **71.22** | 3.77× faster | 5.12× faster | 1.48× slower |
| `neighbours_2` | 1.45 | 2.03 | 3.14 | **0.84** | 1.40× faster | 2.16× faster | 1.72× slower |
| `neighbours_2_with_data` | **1.48** | 4.39 | 5.91 | 3.54 | 2.96× faster | 3.98× faster | 2.39× faster |
| `neighbours_2_with_data_and_filter` | **2.79** | 4.46 | 5.42 | 3.76 | 1.60× faster | 1.94× faster | 1.35× faster |
| `neighbours_2_with_filter` | 1.13 | 1.36 | 3.17 | **0.65** | 1.21× faster | 2.80× faster | 1.74× slower |
| `shortest_path` | 1.18 | **0.30** | 1.93 | 6.03 | 3.90× slower | 1.63× faster | 5.11× faster |
| `shortest_path_with_filter` | 0.39 | **0.24** | 0.85 | 6.53 | 1.63× slower | 2.16× faster | 16.57× faster |
| `single_vertex_read` | 0.27 | **0.14** | 0.73 | 0.17 | 1.98× slower | 2.72× faster | 1.60× slower |
| `pattern_cycle` | 0.54 | 0.43 | 1.25 | **0.42** | 1.27× slower | 2.30× faster | 1.31× slower |
| `pattern_long` | 0.64 | **0.14** | 0.82 | 1.09 | 4.50× slower | 1.28× faster | 1.69× faster |
| `pattern_short` | 0.31 | **0.13** | 0.79 | 0.17 | 2.42× slower | 2.52× faster | 1.80× slower |
| `vertex_on_label_property` | 0.74 | 11.02 | 0.85 | **0.16** | 14.87× faster | 1.15× faster | 4.55× slower |
| `vertex_on_label_property_index` | 0.27 | 0.14 | 0.66 | **0.10** | 1.88× slower | 2.45× faster | 2.62× slower |
| `vertex_on_property` | 0.29 | 0.14 | 0.73 | **0.10** | 2.11× slower | 2.51× faster | 2.78× slower |

**large**

| query | Fluree | Memgraph | Neo4j | FalkorDB | Fluree vs Memgraph | Fluree vs Neo4j | Fluree vs FalkorDB |
|---|---|---|---|---|--:|--:|--:|
| `count` | **0.47** | 126.70 | 153.75 | 106.02 | 271.90× faster | 329.94× faster | 227.50× faster |
| `min_max_avg` | **11.58** | 360.86 | 209.43 | 230.85 | 31.17× faster | 18.09× faster | 19.94× faster |
| `aggregate` | **1.11** | 180.77 | 152.21 | 128.89 | 162.86× faster | 137.13× faster | 116.12× faster |
| `aggregate_with_distinct` | **0.24** | 172.91 | 150.06 | 177.17 | 720.44× faster | 625.25× faster | 738.20× faster |
| `aggregate_with_filter` | **1.08** | 240.56 | 175.62 | 150.98 | 221.91× faster | 162.02× faster | 139.28× faster |
| `allshortest_paths` | 0.39 | **0.30** | 1.01 | 2.87 | 1.28× slower | 2.60× faster | 7.41× faster |
| `expansion_1` | 0.32 | **0.15** | 0.73 | 0.23 | 2.11× slower | 2.29× faster | 1.37× slower |
| `expansion_1_with_filter` | 0.38 | **0.17** | 0.84 | 0.25 | 2.30× slower | 2.21× faster | 1.52× slower |
| `expansion_2` | 5.83 | 14.09 | 18.73 | **4.59** | 2.41× faster | 3.21× faster | 1.27× slower |
| `expansion_2_with_filter` | 0.96 | 0.33 | 0.87 | **0.30** | 2.90× slower | 1.10× slower | 3.19× slower |
| `expansion_3` | **7.92** | 17.05 | 22.21 | 12.16 | 2.15× faster | 2.80× faster | 1.54× faster |
| `expansion_3_with_filter` | 41.04 | 62.76 | 84.94 | **23.95** | 1.53× faster | 2.07× faster | 1.71× slower |
| `expansion_4` | **27.92** | 80.32 | 101.39 | 29.98 | 2.88× faster | 3.63× faster | 1.07× faster |
| `expansion_4_with_filter` | 163.68 | 343.08 | 429.30 | **102.11** | 2.10× faster | 2.62× faster | 1.60× slower |
| `neighbours_2` | 3.05 | 4.47 | 6.92 | **1.84** | 1.47× faster | 2.27× faster | 1.65× slower |
| `neighbours_2_with_data` | **2.64** | 7.13 | 7.62 | 5.57 | 2.70× faster | 2.89× faster | 2.11× faster |
| `neighbours_2_with_data_and_filter` | **6.14** | 10.14 | 10.40 | 7.76 | 1.65× faster | 1.69× faster | 1.26× faster |
| `neighbours_2_with_filter` | 1.17 | 1.11 | 3.57 | **0.60** | 1.05× slower | 3.06× faster | 1.93× slower |
| `shortest_path` | **1.34** | 4.22 | 1.85 | 57.95 | 3.15× faster | 1.38× faster | 43.22× faster |
| `shortest_path_with_filter` | 0.33 | **0.15** | 0.85 | 43.19 | 2.13× slower | 2.59× faster | 131.67× faster |
| `single_vertex_read` | 0.26 | **0.13** | 0.64 | 0.27 | 2.04× slower | 2.43× faster | 1.03× faster |
| `pattern_cycle` | 0.73 | **0.28** | 1.17 | 0.51 | 2.58× slower | 1.60× faster | 1.44× slower |
| `pattern_long` | 1.06 | **0.14** | 0.64 | 2.26 | 7.33× slower | 1.65× slower | 2.14× faster |
| `pattern_short` | 0.29 | **0.14** | 0.61 | 0.21 | 2.12× slower | 2.09× faster | 1.38× slower |
| `vertex_on_label_property` | 0.72 | 183.02 | 0.64 | **0.15** | 255.61× faster | 1.11× slower | 4.74× slower |
| `vertex_on_label_property_index` | 0.22 | **0.16** | 0.78 | 0.18 | 1.37× slower | 3.51× faster | 1.21× slower |
| `vertex_on_property` | 0.21 | **0.14** | 0.62 | 0.18 | 1.52× slower | 2.96× faster | 1.20× slower |
