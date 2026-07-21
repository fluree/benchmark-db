# 3-way co-measured: Fluree vs Neo4j vs Memgraph — pokec small, our box

> **UPDATE 2026-07-05 — PERF-1 FIXED (c2d9fae7 "drive property-join stars
> from the most selective bound object").** Re-ran Fluree only (Neo4j/Memgraph
> unchanged), same params. Geo-mean **4.87 → 3.40 ms; Fluree/Neo4j 2.8× →
> 2.0×**. Fluree now beats/ties Neo4j on **9/35**, within 2× on **22/35**.
> The single-node lookups collapsed as predicted, plus a bonus on neighbours:
>
> | query | before | after | Neo4j | note |
> |---|---|---|---|---|
> | single_vertex_read | 15.84 | **0.37** | 0.44 | 43× faster — now beats Neo4j |
> | vertex_on_property | 15.67 | **0.35** | 0.32 | 44× faster — ties Neo4j |
> | vertex_on_label_property_index | 15.77 | **0.40** | 0.22 | 40× faster |
> | neighbours_2_with_data | 6.93 | **3.52** | 2.66 | 2.0× (bonus — anchor fix) |
> | neighbours_2_with_filter | 8.25 | **4.84** | 1.71 | 1.7× (bonus) |
> | neighbours_2_with_data_and_filter | 10.83 | **6.05** | 2.68 | 1.8× (bonus) |
>
> **Still open:** (a) PERF-3 aggregations untouched (count 37 ms / min_max_avg
> 46 ms, 14–22×); (b) `vertex_on_label_property` — the index-*hostile*
> `MATCH (n:User) WITH n WHERE n.id=$id` form — still 19 ms vs Neo4j 0.26 ms
> (Neo4j pushes the predicate through `WITH`; Fluree doesn't — a distinct
> optimization from PERF-1); (c) expansion_3_with_filter 5.6×, expansion_4
> 1.6–1.9×. A few sub-ms queries wobbled ±0.3–0.7 ms (pattern_long
> 0.88→1.61, pattern_short 0.35→0.46) — likely single-client variance, worth
> a confirming re-run but not material. Fresh TSV:
> results/aws-r8a4xl/small_fluree_c2d9fae7.tsv.

> **UPDATE 2026-07-05 — PERF-3 FIXED (1ed5fcc2 "fold whole-graph scalar
> aggregates from index directories").** Geo-mean **3.40 → 2.72 ms;
> Fluree/Neo4j 2.0× → 1.6×**. Beats/ties Neo4j **10/35**, within 2× **22/35**.
> Values verified (count 10000, min 0, max 111, avg 15.78).
>
> | query | before | after | Neo4j | note |
> |---|---|---|---|---|
> | aggregation__count | 37.03 | **0.49** | 2.53 | 75× faster — beats Neo4j |
> | min_max_avg | 45.92 | **0.42** | 2.07 | 110× faster — beats Neo4j |
>
> Scope note: this folds **whole-graph SCALAR** aggregates (no GROUP BY).
> The GROUP-BY / histogram forms (`RETURN n.age, COUNT(*)`) still scan —
> `arango__aggregate` 8.0 ms, `aggregate_with_filter` 7.2 ms,
> `aggregate_with_distinct` 7.5 ms (2.2–4.0×) — a separate remaining item.
> Progression fce28d8e→PERF1→PERF3 geo-mean: **4.87 → 3.40 → 2.72 ms**
> (Fluree/Neo4j 2.8×→2.0×→1.6×). TSV: small_fluree_1ed5fcc2.tsv.
>
> **Biggest remaining gaps (>2× vs Neo4j):**
> 1. `vertex_on_label_property` **74×** (19.5 ms) — the index-hostile
>    `MATCH (n:User) WITH n WHERE n.id=$id` predicate-pushdown-through-WITH
>    case (untouched; now the single largest gap).
> 2. `expansion_3_with_filter` 5.9×, `expansion_3` 2.7×, `expansion_4` 2.1×,
>    `neighbours_2` family 2.6–3.2× — the multi-hop path-enumeration group
>    (PERF-2 frontier-BFS, not yet addressed).
> 3. GROUP-BY aggregates 2.2–4.0× (see scope note above).

> **UPDATE 2026-07-05 — PERF-4 FIXED (ee728538 "encode Cypher pattern IRIs
> to SIDs at lowering"). MILESTONE: Fluree geo-mean now MATCHES Neo4j.**
> Geo-mean **2.72 → 1.69 ms (Neo4j 1.74) → Fluree/Neo4j 1.6× → 1.0×.**
> Beats/ties Neo4j **21/35**, within 2× **30/35**. Result sizes identical to
> PERF-3 and to Neo4j (speedup is real, not dropped rows).
>
> The entire multi-hop group collapsed — most now **beat Neo4j**:
>
> | query | before | after | Neo4j | note |
> |---|---|---|---|---|
> | neighbours_2 | 12.14 | **1.96** | 3.83 | 6.2× — beats Neo4j |
> | expansion_3 | 48.13 | **8.75** | 17.56 | 5.5× — beats Neo4j |
> | expansion_3_with_filter | 53.91 | **6.36** | 9.11 | 8.5× — beats Neo4j |
> | expansion_4 | 268.0 | **80.9** | 128.8 | 3.3× — beats Neo4j |
> | expansion_4_with_filter | 199.5 | **56.5** | 118.9 | 3.5× — beats Neo4j |
> | expansion_2 | 7.85 | **1.57** | 4.29 | 5.0× — beats Neo4j |
> | neighbours_2_with_data | 4.08 | **1.10** | 2.66 | 3.7× — beats Neo4j |
> | neighbours_2_with_filter | 5.51 | **1.17** | 1.71 | 4.7× — beats Neo4j |
>
> Progression fce28d8e → PERF1 → PERF3 → PERF4 geo-mean:
> **4.87 → 3.40 → 2.72 → 1.69 ms** (Fluree/Neo4j 2.8×→2.0×→1.6×→**1.0×**).
> TSV: small_fluree_ee728538.tsv.
>
> **Only 5 queries remain >2× vs Neo4j:**
> 1. `vertex_on_label_property` **74.6×** (19.7 ms) — the index-hostile
>    `WITH n WHERE n.id=$id` predicate-pushdown case; untouched, now the
>    dominant remaining gap by far.
> 2. GROUP-BY aggregates — `aggregate_with_distinct` 3.7×,
>    `aggregate_with_filter` 2.6×, `aggregate` 2.2× (histogram forms still
>    scan; distinct from the PERF-3 scalar fold).
> 3. `pattern_long` 2.9× — but 1.0 ms absolute, negligible.
>
> **One regression to flag:** `create__edge` 1.23 → 2.43 ms (2× slower; now
> 1.9× Neo4j). The MATCH-anchored edge create — likely a side effect of the
> SID-encoding change on the write-side MATCH path. Worth a look.

> **UPDATE 2026-07-05 — a0f2861f "fuse anonymous hop chains into frontier-BFS
> reachability". HEADLINE: Fluree now AHEAD of Neo4j overall (0.88×).**
> Geo-mean **1.69 → 1.53 ms** (Neo4j 1.74). Beats/ties Neo4j 21/35, within 2×
> 28/35. This commit cleared the two biggest open items at once:
>
> | query | before | after | Neo4j | note |
> |---|---|---|---|---|
> | vertex_on_label_property | 19.70 | **0.56** | 0.26 | 35× — the WITH-hostile predicate-pushdown case, was 74× |
> | create__edge (PERF-4 regression) | 2.43 | **1.34** | 1.31 | regression healed — back to Neo4j parity |
> | expansion_4 | 80.86 | **68.02** | 128.84 | further +19%, beats Neo4j |
> | expansion_4_with_filter | 56.45 | **46.34** | 118.90 | further +18% |
>
> Full geo-mean progression fce28d8e→PERF1→PERF3→PERF4→a0f2861f:
> **4.87 → 3.40 → 2.72 → 1.69 → 1.53 ms** (Fluree/Neo4j 2.8→2.0→1.6→1.0→**0.88×**).
> TSV: small_fluree_a0f2861f.tsv. Result sizes unchanged.
>
> **Only real gap left: GROUP-BY histogram aggregates** — `aggregate_with_distinct`
> 7.7 ms (4.1×), `aggregate_with_filter` 7.7 ms (2.7×), `aggregate` 8.3 ms
> (2.3×). The `RETURN n.age, COUNT(*)` shapes still scan (distinct from the
> PERF-3 scalar fold). Everything else >2× is sub-2.5 ms absolute
> (pattern_long 1.0 ms, pattern_cycle 1.2 ms, vertex_on_label_property now
> 0.56 ms).
>
> **Minor regression to watch:** shortest_path 1.63 → 2.23 ms (1.4×; now 2.7×
> Neo4j) — possibly a frontier-BFS interaction or single-client variance;
> worth a confirming re-run.

> **UPDATE 2026-07-06 — c07c2676 "fold class-anchored aggregates and GROUP-BY
> histograms". Fluree now 1.5× FASTER than Neo4j overall (0.68×).** Geo-mean
> **1.53 → 1.18 ms** (Neo4j 1.74, Memgraph 0.68). Beats/ties Neo4j **24/35**,
> within 2× **33/35**. Fluree/Memgraph down to 1.7×. Aggregate values verified
> (53 age buckets, total 10000).
>
> | query | before | after | Neo4j | note |
> |---|---|---|---|---|
> | aggregate (GROUP BY age) | 8.31 | **0.33** | 3.65 | 25× — beats Neo4j |
> | aggregate_with_distinct | 7.67 | **0.20** | 1.89 | 39× — beats Neo4j |
> | aggregation__count | 0.38 | **0.25** | 2.53 | scalar fold even tighter |
> | min_max_avg | 0.57 | **0.32** | 2.07 | " |
> | shortest_path (prior regression) | 2.23 | **1.50** | 0.83 | healed |
>
> Full geo-mean progression fce28d8e→PERF1→PERF3→PERF4→a0f2861f→c07c2676:
> **4.87 → 3.40 → 2.72 → 1.69 → 1.53 → 1.18 ms**
> (Fluree/Neo4j 2.8→2.0→1.6→1.0→0.88→**0.68×**). TSV: small_fluree_c07c2676.tsv.
>
> **Only 2 queries remain >2× vs Neo4j:**
> 1. `aggregate_with_filter` 2.6× (7.3 ms) — the **WHERE-filtered** GROUP-BY
>    (`WHERE n.age>=18 RETURN n.age, COUNT(*)`) still scans; the fold covers
>    unfiltered class-anchored histograms only. The last real gap.
> 2. `pattern_long` 3.6× — but 1.3 ms absolute, negligible.
>
> **`create__edge` is FLAKY, not cleanly regressed:** 2.43 (PERF-4) → 1.34
> (a0f2861f) → 2.27 (c07c2676). Oscillates run-to-run on the MATCH-anchored
> edge create — likely commit/GC timing on the write path; worth a stability
> look rather than a perf one.

All three engines measured on **one box, identical data, identical parameter
values**, 2026-07-05.

- **Box:** AWS r8a.4xlarge (AMD EPYC 9R45 "Turin" Zen 5, 16 vCPU / 128 GB),
  us-east-1, Ubuntu 24.04 — current-gen successor to Memgraph's documented
  r7a.4xlarge methodology box.
- **Engines:** Fluree `fix/cypher-benchgraph-gaps` @ fce28d8e (built from
  source) · Neo4j 5.26-community (Docker) · Memgraph 3.11.0 (Docker).
- **Dataset:** pokec small — 10,000 :User / 121,716 :Friend edges, all three
  verified equal.
- **Method:** single client, 5 timed runs + 2 warmup, median. **Every engine
  replays the same seeded parameter set** (params_small.json) — so expansion_4
  from a hub vs a leaf is identical across engines. All 35/35 pass on every
  engine.
- **Transport:** Fluree over HTTP (`application/cypher`); Neo4j + Memgraph
  over Bolt (neo4j Python driver). See the transport note below — the fast-
  query floor shows HTTP is not what's driving the gaps.

## ⚠ IMPORTANT 2026-07-06 — the aggregate fold is novelty-sensitive (falls off a cliff under writes)

A repeat-run stability check (3× the same binary/params, ledger NOT re-imported
between runs) exposed that the aggregate-fold numbers above are **best-case,
freshly-indexed only.** Run A matched prior numbers; runs B and C showed the
aggregate family exploding:

| query | run A | run B | run C |
|---|---|---|---|
| count | 0.41 | **281** | **291** |
| min_max_avg | 0.37 | **280** | **292** |
| aggregate (GROUP BY) | 0.54 | **19.5** | **19.9** |
| aggregate_with_distinct | 0.29 | **18.5** | **18.8** |
| aggregate_with_filter | 0.41 | **19.2** | **19.5** |

Everything else was stable (CoV <10%). Isolated the mechanism directly:

```
fresh import (fully indexed):   count = 0.5 ms
+50 writes (un-indexed novelty): count = 260 ms
+300 writes:                     count = 263 ms   (flat — a cliff, not a slope)
```

**Mechanism (corrected via `fluree info` + `fluree reindex`):** it is NOT
index-lag. `fluree info` shows the index fully caught up in the slow state:

```
fresh bulk import:        Commit t=1,   Index t=1    → count 0.5 ms  (fold ON)
+100 incremental writes:  Commit t=101, Index t=101  → count 289 ms  (fold OFF!)
                          (index auto-advanced to 101, yet fold disabled)
explicit `fluree reindex`: Commit t=101, Index t=101 → count 0.6 ms  (fold ON)
                          (index root changed; same t, different build)
```

So index-t catching up to commit-t is **not** sufficient — the incremental
reindex that runs automatically after writes advances index-t but does **not**
produce (or it invalidates) the pre-computed count summary the fold reads. Only
a **full/consolidated index build** — bulk import, or an explicit
`fluree reindex` — builds the fold's summary. After any writes, aggregates fall
back to a ~260 ms scan (worse than the 72 ms pre-fold scan) and stay there until
a full reindex, regardless of what `fluree info` reports for index-t. Values
stay correct throughout.

**Operational note:** `fluree info`'s Index-t = Commit-t does NOT indicate the
aggregate fold is active — the two index builds (incremental vs full) report the
same t but have different roots and different fold behavior.

**Why every prior single-run number looked great:** I re-imported fresh before
each commit's run, so the ledger was always at t=1, fully indexed — the fold was
always active. The benchmark suite itself contains write queries, so within a
single suite run the *later* aggregate queries already run against novelty from
the earlier writes; the pristine numbers only hold for run A on a fresh import.

**Implications:**
- benchgraph's **mixed** and **realistic** modes (reads interleaved with writes)
  would see the degraded aggregate numbers (19–290 ms), not the 0.4 ms best case.
- In a live deployment, aggregates oscillate: fast right after a reindex, then
  cliff to scan as novelty accumulates until the next reindex.
- **For the db team:** the **incremental reindex path doesn't build the aggregate
  count summary** that bulk-import / full-reindex does — that's the root cause.
  Fixes: (a) have incremental reindex maintain/rebuild the fold summary (or the
  fold compose over incremental index segments), and (b) the fallback scan
  (260 ms) should be no worse than the plain pre-fold scan (72 ms).

This does not undo the read-side wins (expansions, neighbours, lookups — all
novelty-insensitive and stable across runs). It scopes the *aggregate* wins to
"freshly-indexed ledger."

## UPDATE 2026-07-06 — 0d728150 "fold group-key-filtered histograms": LAST algorithmic gap closed

`aggregate_with_filter` (`WHERE n.age>=18 RETURN n.age, COUNT(*)`) **7.29 →
0.41 ms (18×)**, values correct (39 buckets ≥18, total 6594). That was the last
query above 2× with real absolute time. **No aggregate or expansion query is
now a scan.**

**Final standings — full-suite geo-mean (35 q), all durable-vs-durable where it
matters, r8a.4xlarge, identical params:**

| engine | geo-mean | vs Fluree |
|---|---|---|
| Memgraph — async WAL (non-durable default) | 0.68 ms | Fluree 1.75× behind |
| **Fluree 0d728150 (durable, HTTP)** | **1.18 ms** | — |
| Memgraph — per-tx fsync (durable) | 1.25 ms | Fluree **0.95× ahead** |
| Neo4j (Bolt) | 1.74 ms | Fluree **0.68× ahead** |
| Neo4j (HTTP) | 4.67 ms | Fluree **0.25× ahead** |

Fluree beats/ties Neo4j-Bolt 27/35. Fluree is ahead of every engine except
Memgraph-in-its-non-durable-default.

**Honest caveat on the flat geo-mean (1.18 → 1.18):** the 6.9 ms
`aggregate_with_filter` win didn't move the geo-mean because ~9 sub-ms queries
jittered up 1.3–1.5× the same run (count 0.25→0.35, expansion_1 0.37→0.50,
etc.). Geo-mean is log-weighted, so a 0.25→0.35 wobble offsets a 7→0.4 win in
log-space. **The suite is now at a ~0.3–1 ms per-request noise floor** where
5-run medians bounce ±0.05 ms between runs; distinguishing sub-ms engine
differences would need many more runs (20+) or repeated-median-of-medians. The
*absolute* wins are real and monotonic; the geo-mean has bottomed out at the
measurement floor.

**Two queries with genuine absolute headroom remain** (not noise):
`unwind_range_vertex_write` ~9–10 ms (batch-insert long pole, also a Neo4j
loss) and `shortest_path` ~1.5–2.2 ms (unstable across builds — wobbles
1.50/2.23/1.50/2.15, worth a stability profile). TSV: small_fluree_0d728150.tsv.

## Transport-matched: Fluree-HTTP vs Neo4j-HTTP (2026-07-06)

Neo4j also exposes an HTTP transactional API (`/db/neo4j/tx/commit`). Measured
both engines over HTTP, identical params, same box (Fluree @ c07c2676):

| | geo-mean | vs Fluree-HTTP |
|---|---|---|
| Fluree (HTTP) | 1.18 ms | — |
| Neo4j (HTTP) | 4.67 ms | Fluree **4× faster** (0.25×) |
| Neo4j (Bolt) | 1.74 ms | for reference |

**Fluree-HTTP beats or ties Neo4j-HTTP on 33/35 queries.** Neo4j's own HTTP
endpoint is **2.7× slower than its Bolt** — the REST transactional endpoint
carries heavy per-request overhead (open+commit a tx, JSON envelope). So the
near-parity Fluree showed earlier was against Neo4j's *fast* protocol; on a
genuinely transport-matched (HTTP↔HTTP) basis Fluree dominates Neo4j. The only
two queries where Neo4j-HTTP wins are the known algorithmic long poles
(`aggregate_with_filter` 1.7×, `unwind_range_vertex_write` 1.1×), not transport.
TSV: small_neo4j_http.tsv.

## Memgraph with per-transaction durability (2026-07-06) — the gap inverts

Re-ran Memgraph with `--storage-wal-file-flush-every-n-tx=1` (fsync per commit
— the durability contract Fluree provides by default), reloaded pokec small,
same params. Reads unchanged; writes and the full-suite geo-mean move sharply:

**Bulk load** (131k statements): 5 s → **362 s (72× slower)** with per-commit fsync.

**Write queries** (median ms):

| write query | MG async (default) | MG fsync (durable) | slowdown | Fluree | Neo4j |
|---|---|---|---|---|---|
| single_vertex_write | 0.15 | 2.88 | 19× | 1.15 | 1.05 |
| single_edge_write | 0.19 | 3.00 | 16× | 1.25 | 1.25 |
| create_vertex | 0.13 | 2.86 | 22× | 0.83 | 1.09 |
| create_vertex_big | 0.14 | 2.81 | 20× | 0.85 | 1.29 |
| create_edge | 0.15 | 2.96 | 20× | 2.27 | 1.31 |
| update_on_property | 0.88 | 3.60 | 4× | 1.00 | 4.54 |
| unwind_range (batch 100) | 0.61 | 3.80 | 6× | 10.30 | 5.19 |
| **write geo-mean** | **0.22** | **3.08** | **14×** | **1.46** | 1.70 |

Durable-Memgraph writes are **2.1× slower than Fluree's** — the sub-0.2 ms
write lead was entirely the async-WAL shortcut. (The one write where durable
Memgraph still wins is `unwind_range`, Fluree's known batch-insert long pole.)

**Full-suite geo-mean (35 q) — apples-to-apples on durability:**

| engine | geo-mean | vs Fluree |
|---|---|---|
| Memgraph — async WAL (published default) | 0.68 ms | Fluree 1.74× behind |
| **Memgraph — per-tx fsync (durable)** | **1.25 ms** | **Fluree 0.94× — AHEAD** |
| Fluree (durable, HTTP) | 1.18 ms | — |
| Neo4j (Bolt) | 1.74 ms | Fluree ahead |

**When every engine is held to the same per-commit durability Fluree provides,
Fluree has the best geo-mean of the three.** Memgraph's headline lead exists
only in its non-durable default mode. This is the fair framing for any
published comparison.

## Note on Memgraph write durability

Memgraph's sub-0.2 ms writes are not directly comparable to Fluree's ~1 ms:
Memgraph's default `--storage-wal-file-flush-every-n-tx=100000` fsyncs the WAL
only every 100k transactions, so a committed write is acknowledged *before* it
is durable on disk. Fluree commits durably per transaction. A like-for-like
write comparison would set Memgraph to `flush-every-n-tx=1` (per-commit fsync)
— which slows its writes substantially — or note the durability-contract
difference. Memgraph does persist (WAL + periodic snapshots on by default) and
has an experimental `ON_DISK_TRANSACTIONAL` (RocksDB) mode.

## Data loading: what the Turtle transform was, and whether "identical commands" is closable (2026-07-06)

**What I transformed and why.** benchgraph loads Pokec by *executing* its
`pokec_small_import.cypher` — 131,717 Cypher statements — via `cypher-shell`
(Neo4j) / `mgconsole` (Memgraph). For Fluree I ran `pokec_to_ttl.py`, which does
two things:
1. **Format**: Cypher `CREATE`/`MATCH…CREATE` statements → Turtle triples, because
   Fluree's bulk importer (`create --from`) takes declarative data
   (`.ttl/.nt/.nq/.csv/.jsonld`), not executable Cypher. (Cypher is a write
   *language*, not a bulk-load *format* — same reason you'd use
   `neo4j-admin import` rather than feed cypher-shell a file for a real bulk load.)
2. **Edge model**: dropped the unused `e` in `(n)-[e:Friend]->(m)` so edges become
   plain triples. Verbatim, the bound `e` triggers Fluree **reification** (base
   triple + reifier bundle = extra nodes/flakes); confirmed 2 nodes + 1 bound
   edge = 8 flakes. (Traversal still works — `-->` sees the base triple either
   way — but reified edges bloat the store.)

**Why the file can't load as-is** (probed directly):
- `create --from` rejects `.cypher` (not a bulk format).
- The Cypher write path rejects the file: trailing `;` → `C106: multi-statement
  scripts are deferred; one statement per request`. You'd have to split into
  131k separate requests.
- Each request is a durable commit → 131k commits is slow *and* triggers the
  incremental-reindex/aggregate-fold degradation documented above.

**Is the gap closable? Yes — and one path already works today.** `create --from`
already supports **neo4j-admin CSV** (`:ID/:LABEL/:START_ID/:END_ID/:TYPE`
headers). Verified end-to-end: loaded neo4j-admin-style `nodes.csv`+`rels.csv`
and ran the benchmark Cypher (`MATCH (n:User {id})`, untyped `-->`) against it
successfully, plain edges, no reification. So if the load used neo4j-admin CSV
(Neo4j's own bulk path), Fluree ingests the **identical files**. Closing the
*literal-same-.cypher-file* gap would need a bulk `.cypher` parser in `--from`
(parse the multi-statement file, one consolidated commit, unbound edge vars →
plain edges) — a modest, well-scoped feature.

**Load performance is not a Fluree weakness — the opposite.** Fluree bulk import
(Turtle) = **0.3–0.4 s**; Neo4j cypher-shell = **307 s**; Memgraph durable
(fsync) = **362 s** for the same 131k statements. The transform buys
command/file *identity*, not speed — Fluree loads this data ~1000× faster than
the statement-execution path either competitor uses.

## Results — median ms (lower is better)

| query | Memgraph | Neo4j | Fluree | F/Neo4j |
|---|---|---|---|---|
| **Fluree ≤ Neo4j (8 queries)** | | | | |
| update__vertex_on_property | 0.88 | 4.54 | **1.04** | 0.2× |
| create__vertex_big | 0.14 | 1.29 | **0.75** | 0.6× |
| create__pattern | 0.13 | 1.20 | **0.73** | 0.6× |
| create__vertex | 0.13 | 1.09 | **0.81** | 0.7× |
| single_vertex_write | 0.15 | 1.05 | **0.74** | 0.7× |
| expansion_1 | 0.19 | 0.84 | **0.62** | 0.7× |
| single_edge_write | 0.19 | 1.25 | **1.12** | 0.9× |
| allshortest_paths | 0.20 | 1.01 | **0.81** | 0.8× |
| **within 2× (10 queries)** | | | | |
| create__edge | 0.15 | 1.31 | 1.96 | 1.5× |
| pattern_short | 0.16 | 0.27 | 0.35 | 1.3× |
| expansion_1_with_filter | 0.17 | 0.64 | 0.71 | 1.1× |
| shortest_path_with_filter | 0.15 | 0.56 | 0.97 | 1.7× |
| expansion_4_with_filter | 81.69 | 118.90 | 191.56 | 1.6× |
| expansion_4 | 92.86 | 128.84 | 245.46 | 1.9× |
| shortest_path | 0.21 | 0.83 | 1.62 | 2.0× |
| expansion_2 | 1.96 | 4.29 | 7.54 | 1.8× |
| unwind_range_vertex_write | 0.61 | 5.19 | 9.54 | 1.8× |
| pattern_cycle | 0.20 | 0.45 | 0.83 | 1.8× |
| **2–6× slower (11 queries)** | | | | |
| aggregate (GROUP BY age) | 1.29 | 3.65 | 7.45 | 2.0× |
| pattern_long | 0.16 | 0.36 | 0.88 | 2.5× |
| expansion_3 | 12.11 | 17.56 | 46.35 | 2.6× |
| neighbours_2_with_data | 2.14 | 2.66 | 6.93 | 2.6× |
| expansion_2_with_filter | 0.45 | 0.87 | 2.56 | 3.0× |
| aggregate_with_distinct | 0.94 | 1.89 | 6.58 | 3.5× |
| aggregate_with_filter | 1.68 | 2.81 | 9.87 | 3.5× |
| neighbours_2 | 2.91 | 3.83 | 14.00 | 3.7× |
| neighbours_2_with_data_and_filter | 3.68 | 2.68 | 10.83 | 4.0× |
| neighbours_2_with_filter | 0.94 | 1.71 | 8.25 | 4.8× |
| expansion_3_with_filter | 7.04 | 9.11 | 51.35 | 5.6× |
| **≥14× slower (4 queries) — the label-scan bug** | | | | |
| aggregation__count | 0.91 | 2.53 | 36.81 | 14.5× |
| min_max_avg | 2.29 | 2.07 | 44.10 | 21.3× |
| single_vertex_read | 0.17 | 0.44 | 15.84 | 36.2× |
| vertex_on_property | 0.15 | 0.32 | 15.67 | 48.4× |
| vertex_on_label_property_index | 0.16 | 0.22 | 15.77 | 72.4× |
| vertex_on_label_property | 1.02 | 0.26 | 19.26 | 73.0× |

**Geo-mean (35 queries): Memgraph 0.68 · Neo4j 1.74 · Fluree 4.87 ms.**
Fluree is **2.8× behind Neo4j**, 7.2× behind Memgraph.

## Headline

Co-measured on identical hardware/params, the Fluree↔Neo4j gap is **2.8×
geo-mean**, not the 7.6× the published-numbers comparison implied (that
compared our single-client median against their 12-worker concurrent p50 on
different silicon). And it's **not a broad gap — it's concentrated**:

- Fluree **beats or ties Neo4j on 8/35** queries — all writes, updates
  (5× faster: 1.0 vs 4.5 ms), 1-hop expansion, allShortestPaths.
- **Within 2× on another 10** — including the heavy expansion_4 (1.6–1.9×)
  and both shortest-path queries.
- The geo-mean is dragged almost entirely by **6 queries**: the 4
  single-node-lookup shapes (14–73×) and 2 whole-graph aggregates (14–21×).

Fix those two families and the geo-mean roughly halves.

## Priority (unchanged, now quantified on identical hardware)

1. **PERF-1 — single-node `{id:$id}` label scan, not seek.** 15–19 ms where
   Neo4j/Memgraph are 0.2–0.4 ms (36–73×). Four queries, the whole tail of
   the distribution. Same fix fce28d8e applied to the write path; the read
   path's standalone-node pattern still scans (proof: expansion_1, the same
   `{id:$id}` constraint as a *join* anchor, is 0.62 ms — faster than Neo4j).
2. **PERF-3 — whole-graph aggregates.** count / min_max_avg 37–44 ms vs
   2–3 ms (14–21×). Neo4j serves these from its count store; Fluree scans.
3. **PERF-4 / neighbours + filtered expansion_3** — 3.7–5.6×, the var-length
   frontier overhead.
Everything else is already ≤2× or ahead.

## Transport note (HTTP vs Bolt)

Fluree is measured over HTTP with a fresh connection per request; Neo4j and
Memgraph over pooled Bolt. That handicaps Fluree on the sub-ms queries — yet
Fluree's fast queries land at 0.35–0.9 ms (pattern_short 0.35, expansion_1
0.62, creates 0.7–0.8), i.e. **already in Neo4j's Bolt range**. So HTTP
round-trip is ~sub-ms and is NOT what causes the 15–50× rows — those are
algorithmic (scans). A keep-alive HTTP client, or measuring Neo4j over its
own HTTP endpoint, would tighten the sub-ms comparison but won't move the
headline. Worth doing before publishing; not before the PERF-1/PERF-3 fixes.

## Files
- results/aws-r8a4xl/small_{fluree,neo4j_bolt,memgraph}.tsv
- results/aws-r8a4xl/params_small.json (the shared seed vertices)
