# Fluree Cypher — benchgraph findings & fix list

Open issues surfaced while co-measuring Fluree vs Neo4j vs Memgraph on the
Memgraph benchgraph (Pokec) suite. Context: Fluree `fix/cypher-benchgraph-gaps`
@ 0d728150, AWS r8a.4xlarge, pokec small (10k nodes / 121,716 edges). Seven
perf commits already took the geo-mean from 4.87 → 1.18 ms (ahead of Neo4j-Bolt
and durable Memgraph); these are the items that remain.

Priority order: BUG-1 is the one that would visibly embarrass a published run.
BUG-2 is the only query where Fluree loses to *every* competitor. The rest are
stability/observability/feature items.

---

## BUG-1 — Aggregate fold silently degrades after any write (incremental reindex doesn't rebuild the fold summary) ⚠ HIGHEST

> **Update (6df9cc43 + 40f1095f, 2026-07-06):** BUG-1 fold cliff **FIXED — fast AND
> correct under writes.** After +100 CREATEs + 5 SETs, `count`/`min/max/avg`/`max`
> now run in **0.42/0.57/0.87 ms** (were ~260 ms in 8e96b1d) with fully correct
> values (count 10100, avg 16.122, max 200, 53 buckets Σ10100). `6df9cc43` carries
> base per-graph property stats through incremental indexing; `40f1095f` gates fast
> paths on live novelty. Scalar folds restored to `0d728150` speed. **BUT this
> introduced a NEW regression — see BUG-1b below.**

> **Update (8e96b1d2, 2026-07-05):** the **correctness** half is FIXED. Whole-graph
> aggregates now return correct values under novelty — verified after +100 CREATEs
> (count 10000→10100, avg 15.783→16.122, age-50 bucket 3→103, GROUP-BY buckets sum
> to 10100) and 5× `SET age=200` (max 111→200). The fold no longer silently returns
> stale values. **Speed is not yet addressed** (a separate change is coming): the two
> whole-graph scalar folds (`aggregation__count`, `aggregation__min_max_avg`) now
> always take the full-scan path — 0.35/0.43 ms → **36.8/39.2 ms** on fresh import,
> and ~260 ms under writes. The GROUP-BY fold (`arango__aggregate`) stays fast
> (0.49 ms). Suite geo-mean is 1.18 → 1.47 ms (+24%) — but that delta is *entirely*
> these two queries; excluding them the suite is flat-to-better (1.27 → 1.21 ms,
> −4.6%). So: correct-under-writes now, headline fold speed pending.

**Severity:** High. Turns a headline win (25–110× faster than Neo4j on
aggregates) into a 14–700× *loss* under any read/write workload — i.e. exactly
benchgraph's `mixed`/`realistic` modes and any real deployment.

**Symptom.** The whole-graph / GROUP-BY aggregate fold (commits PERF-3,
c07c2676, 0d728150) is fast only on a freshly bulk-imported ledger. After any
write it cliffs:

| query | fresh import | after ≥1 write |
|---|---|---|
| `MATCH (n) RETURN count(n)` | 0.5 ms | **260 ms** |
| `min(n.age), max, avg` | 0.4 ms | **290 ms** |
| `RETURN n.age, COUNT(*)` (GROUP BY) | 0.5 ms | **19 ms** |

It's a binary cliff, not a slope: +50 writes and +300 writes both give ~260 ms.
Values stay correct throughout.

**Root cause (isolated via `fluree info` + `fluree reindex`).** It is NOT
index-lag. After writes, `fluree info` shows the index fully caught up
(`Commit t = Index t = 101`) yet the fold is off. The *incremental* reindex that
runs automatically after writes advances index-t but does **not** build the
pre-computed count summary the fold reads. Only a **full/consolidated** index
build produces it:

```
fresh bulk import         Commit t=1   Index t=1    count 0.5 ms  fold ON
+100 incremental writes   Commit t=101 Index t=101  count 289 ms  fold OFF
explicit `fluree reindex` Commit t=101 Index t=101  count 0.6 ms  fold ON   (new index root)
```

Also: the disabled-fold fallback scan (~260 ms) is *slower* than the pre-fold
plain scan was (72 ms at base) — a second, separable regression.

**Ideal fix.**
1. Have incremental reindex maintain/rebuild the aggregate count summary (or
   make the fold compose `indexed summary + novelty delta` instead of disabling).
2. Make the fallback path no worse than the plain pre-fold scan.

**Repro.** Fresh import → `count` (fast). One `CREATE` → `count` (slow).
`fluree reindex` → `count` (fast again).

---

## BUG-1b — Novelty-gate is too broad: it disables the point-lookup index-seek fast path (regression introduced by 40f1095f) ✅ FIXED (7cc85653)

> **RESOLVED (7cc85653, 2026-07-06)** "keep specific-value lookups at seek speed
> under predicate novelty." Confirmed: the exact trigger (+7 `CREATE (:UserTemp
> {id})` = id-predicate novelty, then +600 more) now keeps
> `match__vertex_on_label_property` at **0.6–1.2 ms** (was 18–20 ms), rows correct.
> Full-suite value 16.88 → **0.59 ms**. Fold fix from 6df9cc43 still holds
> (count/min-max-avg fast+correct under writes). Suite geo-mean 1.46 → **1.22 ms**
> (back to the 0d728150 peak, now with both fixes). The narrow-gate fix I proposed
> below is what landed.


**Severity:** High. Same shape as BUG-1 but now on point lookups: a headline win
(0.5 ms indexed `WHERE n.id=$id`) cliffs to a **17–20 ms full label-scan** the
moment there is any novelty on the queried predicate.

**Symptom.** `MATCH (n:User) WITH n WHERE n.id = $id RETURN n` (query
`match__vertex_on_label_property`, fixed to 0.52 ms by a0f2861f's predicate
pushdown) regressed to **16.9 ms (32×)** in the full suite under 6df9cc43.

**Root cause (bisected).** `40f1095f` ("gate fast paths on live novelty") gates
the `id`-seek pushdown on live novelty **of the queried predicate**. Confirmed by
isolation:

| state | target `WHERE n.id=$id` |
|---|---|
| fresh import | 0.5–1.2 ms (fast) |
| +600 `CREATE (:User{id,age})` | 1.3 ms (fast) |
| +7 `CREATE (:UserTemp{name})` — label novelty only | 1.2 ms (fast) |
| +7 `CREATE (:UserTemp{id})` — **novelty on `id` predicate** | **18–20 ms (slow)** |
| after explicit `fluree reindex` | 5–6 ms (restored) |

The unique suite trigger is `arango__single_vertex_write`
(`CREATE (:UserTemp {id:$id})`) — the only write that adds novelty to the `id`
predicate. Nothing else in the suite degrades it. Values stay correct throughout;
consolidating novelty via full reindex clears it — identical mechanism to BUG-1.

**Why it's wrong.** A specific-value seek (`id = $id`) is *still correct* under
novelty — you just seek the index **and** the novelty overlay and union. The gate
shouldn't disable the seek at all; disabling it forces a full `:User`
label-scan-then-filter.

**Ideal fix.** Narrow the `40f1095f` gate. Point/range index seeks should
**compose** indexed-seek + novelty-overlay-seek rather than fall back to a scan
when novelty is present. Reserve novelty-gating for the whole-relation summary
paths (folds) where a stale precomputed aggregate would be *wrong*, not for
value-addressed lookups that remain correct.

**Net for 6df9cc43:** the fold fix is a clean win; this is a new, separable
regression from the same commit pair. Suite geo-mean 1.18 → 1.46 ms — but ~all of
the delta is this one query (excluding it, 1.21 → 1.35, and that residual is the
sub-ms noise floor).

---

## BUG-2 — Batch insert (`UNWIND range … CREATE`) doesn't amortize; loses to everyone

**Severity:** Medium-High. The only benchmark query where Fluree is slower than
Neo4j *and* both Memgraph modes.

**Symptom.** `UNWIND range(1,100) AS x CREATE (:L1:…:L7 {…})` — insert 100 nodes
in one statement:

| Fluree | Neo4j | Memgraph (durable fsync) | Memgraph (async) |
|---|---|---|---|
| **9–10 ms** | 5.2 ms | 3.8 ms | 0.6 ms |

~100 µs/node with no batching benefit — the 100 rows appear to be processed as
100 units rather than one staged commit.

**Ideal fix.** Stage the UNWIND-driven creates into a single batched
assert/commit so per-row overhead is amortized (the declarative bulk path
already does this for `--from`; the write path should too).

---

## BUG-3 — `MATCH…CREATE` edge write is unstable run-to-run

**Severity:** Low-Medium (flakiness, not a fixed slowdown).

**Symptom.** `MATCH (a:User {id}),(b:User {id}) CREATE (a)-[:TempEdge]->(b)`
oscillates across otherwise-identical builds: **1.34 / 2.27 / 2.43 ms**. Not
correlated with code changes — looks like commit/GC/index-timing on the
write-side anchored MATCH.

**Ideal fix.** Profile the anchored-MATCH write path for a variable cost
(allocation, commit flush, or index interaction); make latency deterministic.

---

## BUG-4 — `shortestPath` latency is unstable

**Severity:** Low.

**Symptom.** `shortestPath((n)-[*..15]->(m))` wobbles **1.50 / 2.23 / 1.50 /
2.15 ms** across builds — larger variance than its ~1.5 ms absolute would
suggest, and it's 2–3× Neo4j (0.83 ms). Possibly an interaction with the
frontier-BFS changes (a0f2861f).

**Ideal fix.** Profile BFS setup cost; stabilize.

---

## FEATURE-1 — Bulk import of a raw `.cypher` file (load parity with cypher-shell / mgconsole)

**Severity:** Medium (feature; blocks a literal "identical load commands" claim).

**Gap.** benchgraph loads Pokec by executing `pokec_small_import.cypher` (131k
Cypher statements) via `cypher-shell -f` / `mgconsole <`. Fluree can't ingest
that file as-is:
- `create --from` accepts `.ttl/.nt/.nq/.csv/.jsonld` but **not** executable
  `.cypher`.
- The Cypher write path rejects the file: multi-statement scripts are deferred
  (`C106`), so it'd need splitting into 131k requests.
- 131k durable commits would be slow *and* trip BUG-1.
- A bound-but-unused edge var (`(n)-[e:Friend]->(m)`) reifies, changing the data
  model (extra ~121k wrapper nodes).

So today the file must be transformed to Turtle (dropping the unused edge var to
get plain edges). **Data is fully preserved** — verified by identical 1–4-hop
traversal counts vs Neo4j/Memgraph (expansion_4 = 8015 on all three) — but it's
not the same command.

**Ideal fix.** Accept `.cypher`/`.cql` in `create --from`, routed through the
**bulk** path (not the query engine):
1. Parse the multi-statement file (bypass C106 for file import).
2. Two-pass: build `id → subject` from `CREATE` node stmts, resolve
   `MATCH…CREATE` edge endpoints against that map in-memory (no per-edge index
   lookups).
3. Emit consolidated flakes → one full-index commit (keeps sub-second load and a
   working fold).
4. Unbound/unused edge vars → **plain edges by default**; reification opt-in via
   a flag (mirror the existing CSV importer's `annotated | plain`).

Much of the plumbing exists: `create --from` already handles **neo4j-admin CSV**
(verified end-to-end) via the same two-pass/consolidated-commit path — this is
mainly a Cypher front-end parser on top.

**Note:** load is a Fluree *strength*, not a weakness — bulk Turtle import is
~0.3 s vs Neo4j 307 s / durable Memgraph 362 s for the same data. This feature
buys command identity, not speed.

---

## OBSERVABILITY-1 — `fluree info` index-t doesn't reflect fold/query-plan state

**Severity:** Low (but it cost real debugging time here).

`fluree info` reports `Index t = Commit t` in *both* the fold-ON (bulk/full
index) and fold-OFF (incremental index) states — same t, different index root,
opposite aggregate performance. There's no surfaced signal for "is the
consolidated index / aggregate summary current." An operator can't tell from
`info` whether aggregates will run fast.

**Ideal fix.** Surface index build type / summary freshness (e.g. "consolidated
vs incremental", or a "fold available" flag) in `fluree info`.

---

## Not bugs — context for any published comparison

- **Memgraph write durability.** Memgraph's sub-0.2 ms writes use its default
  async WAL (`--storage-wal-file-flush-every-n-tx=100000`) — commits ack before
  durable. Held to per-commit durability (`=1`), Memgraph writes are 3.08 ms
  (14× slower) and Fluree writes are 2.1× faster; full-suite geo-mean flips to
  Fluree-ahead (1.18 vs 1.25 ms). Fair comparisons must match the durability
  contract.
- **Read floor.** Fluree's fastest reads are ~0.3–0.9 ms over HTTP vs Memgraph's
  ~0.15 ms over Bolt. ~0.2 ms of that is HTTP-vs-Bolt transport + parse/plan; a
  plan cache (queries are `$param`-ized → cache key = statement text) could shave
  it. Not a bug; the residual is the durable-DB-vs-in-memory floor.

---

## BOLT-1 — Bolt protocol adapter (feature/bolt @ 869060fa): works end-to-end; only real weakness is node (`RETURN n`) encoding

**Status:** feature/bolt **functional** — drove the full 35-query suite through
the official neo4j Python driver, 35/35 pass, results byte-identical to HTTP.
Updated to 869060fa (bolt now default-on, first-class CLI flags, BOLT-1c fixed,
BOLT-1b partially addressed).

**Setup (869060fa).** Bolt is default-on — plain `cargo build --release -p
fluree-db-cli`, no `--features`. First-class flags on `server run/start/restart`:
`fluree server start --listen-addr 127.0.0.1:8090 --bolt-listen-addr
127.0.0.1:7689 --bolt-default-db pokec:main`. `fluree server status` now reports
`bolt: 127.0.0.1:7689`; `--dry-run` prints the resolved Bolt config. v1 runs open
(no auth; refuses if data_auth_mode=required).

**What works.** Handshake (driver negotiates 5.x), parameterized reads, `RETURN n`
→ proper Bolt `Node` (labels frozenset + property map), multi-hop expansions,
autocommit writes (bare-var `RETURN n`/`RETURN e`, no-RETURN, `SET`, `UNWIND`
batch). Row counts identical to HTTP on every query (neighbours_2_with_data 188,
expansion_4 8015, etc.).

### BOLT-1a — the win: 25–45% faster on small-result queries
Transport savings are real. On point reads / aggregates / small writes Bolt beats
HTTP by the ~0.1–0.2 ms of HTTP framing+JSON I predicted:

| query | HTTP | BOLT |
|---|---|---|
| `aggregation__count` | 0.40 | **0.23** |
| `arango__aggregate_with_distinct` | 0.32 | **0.18** |
| `match__vertex_on_property` | 0.37 | **0.26** |
| `match__vertex_on_label_property_index` | 0.39 | **0.26** |
| `arango__expansion_1` | 0.49 | **0.35** |
| `arango__allshortest_paths` | 1.02 | **0.67** |

This is exactly the fast-query-floor reduction Bolt was supposed to buy — Fluree's
sub-ms reads reach genuine Bolt-class latency (0.18–0.35 ms).

### BOLT-1b — full-node (`RETURN n`) emit is ~2.8× Neo4j-Bolt; everything else is driver overhead ✅ MOSTLY FIXED (f055e0af)

> **RESOLVED-ish (f055e0af, 2026-07-06)** "stop inlining edge adjacency into Bolt
> node property maps" — the fix I proposed. Verified: bare `RETURN n` now emits
> **scalar properties only** (no `Friend` array; label preserved), and edge-var
> queries still surface relationships (`RETURN r` → `Friend`) — Neo4j-correct. Result
> (per-row emit cost, µs/row, which removes the heavy per-param rowcount variance):
> node emit **59→35 and 71→38 µs/row (~45% cut) on both node queries**. Fluree-Bolt
> node emit is now **~1.25–1.6× Neo4j-Bolt** (was 2.4–2.8×) — the adjacency inlining
> was the bulk of the gap, as diagnosed. Raw `neighbours_2_with_data` median
> 7.34→4.33 ms. Suite geo-mean barely moves (1.316→1.309) only because just 2 of 35
> queries return nodes. Residual ~1.3–1.6× vs Neo4j is general per-node property
> packing — a smaller, separate optimization if ever needed. **BOLT-1b effectively
> closed.**

**Corrected root-cause (twice).** 804cde72 blamed all data-heavy queries on node
hydration. Then the HTTP baseline turned out to be **wrong** on node queries (see
HTTP-1): over HTTP, `RETURN n` returns only the subject **IRI string**, not the
node — so Fluree-HTTP was doing almost no work and is **not comparable** on
node-shaped queries. The only fair yardstick for node emit is **Bolt-vs-Bolt**, all
engines returning full `Node` structures through the same neo4j driver:

| query | returns | Flu-BOLT | N4j-BOLT | MG-BOLT | Flu-HTTP |
|---|---|---|---|---|---|
| `neighbours_2_with_data` | full **node** `n` | **7.34** | 2.66 | 2.14 | 1.02 ⚠not-comparable (bare IRI) |
| `neighbours_2_with_data_and_filter` | full **node** | **7.21** | 2.68 | 3.68 | 1.29 ⚠ |
| `neighbours_2` | `n.id` scalar | 4.23 | 3.83 | 2.91 | 1.83 |
| `expansion_2` | `n.id` scalar | **3.03** | 4.29 | 1.96 | 1.41 |
| `expansion_3` | `n.id` scalar | 19.91 | 17.56 | 12.11 | 8.97 |
| `expansion_4` | `n.id` scalar | **107.7** | 128.84 | 92.86 | 66.45 |

- **Scalar multi-row (`expansion_*`, `neighbours_2`): NOT a Fluree bug.** Fluree-Bolt
  is competitive with Neo4j-Bolt — *beats* it on expansion_2 and expansion_4, ties
  elsewhere. The gap vs Fluree-HTTP is the neo4j driver's per-`Record` construction
  (urllib+`json.loads` bulk-parses rows faster than the driver builds Python
  objects); Neo4j and Memgraph pay the identical tax over Bolt. Client-library
  artifact, not the server.
- **Full-node emit (`RETURN n`): the one genuine Fluree-Bolt gap, ~2.8× Neo4j.**
  Verified Fluree-Bolt returns a *correct, complete* node (id, age, gender,
  completion_percentage, Friend edge list) — same payload as Neo4j — just ~2.8×
  slower (7.3 vs 2.66 ms). `cbe40aff` ("make Bolt node hydration actually engage and
  actually parallel") only shaved ~9% (8.03 → 7.34), so the SPOT-read parallelism it
  added isn't the bottleneck. Suspect a per-node fan-out of individual property
  lookups (vs Neo4j's stored-node adjacency). Needs a profiler pass on the full-node
  hydration path. This is the last real Fluree-Bolt weakness.

### BOLT-1c — write-RETURN typed nodes ✅ FIXED (cb62f1fc)
`CREATE (n:UserTemp {id}) RETURN n` over Bolt now returns a proper `Node`
(`type=Node`, `labels={'UserTemp'}`), matching the read path. (Was a bare string at
804cde72.) Write-RETURN property expressions remain a documented v1 limit.

### Net (transport-matched — the headline Bolt enables)
Same 869060fa binary, geo-mean over 35 queries: **HTTP 1.157 ms / Bolt 1.333 ms**.
Bolt is slightly worse *overall* only because of the driver's per-row tax on the
handful of big multi-row reads (+ BOLT-1b's node-encode query) — the small-result
wins (25–45% faster, count 0.40→0.23) are real. The comparison it unlocks is the
point: **Fluree-Bolt 1.333 vs Neo4j-Bolt 1.739 → Fluree 1.30× faster on the
identical protocol/driver**, and Fluree-Bolt beats or ties Neo4j-Bolt on the big
expansion queries. The only place Fluree-Bolt genuinely trails Neo4j-Bolt is
`RETURN n` node encoding (BOLT-1b). Fix that and Bolt is a clean win top to bottom.

### BOLT-1b addendum — why node emit is heavy: Fluree inlines edge adjacency into the Node
The Bolt `Node` is **truly materialized** — every stored property packed inline in
the single result message, eagerly, no lazy/async back-fetch (the protocol has no
deferred-property mechanism). Verified vs TTL ground truth for `u:4062`: all four
stored scalars present, correct. **But Fluree also folds the node's outgoing edges
into the property map** (`Friend: [target IRIs...]`) — a Neo4j `Node` carries only
scalar properties, never adjacency. So Fluree emits *more* per node than Neo4j, and
per-node cost **scales with out-degree**. For `neighbours_2_with_data` (returns
~100–188 nodes, each dragging its full friend list) that compounds — the likely
bulk of the ~2.8× gap. **Fix direction:** don't inline edge adjacency into Bolt
`Node` property maps (Neo4j returns relationships only when the query binds an edge
var / path); emit just scalar properties for a bare node var. That alone should
close most of BOLT-1b and is also more Neo4j-semantics-correct.

---

## HTTP-1 — `RETURN n` (bare node var) over the HTTP/cypher-json surface returns only the subject IRI, not the node ⚠

**Severity:** Medium (correctness/parity). The HTTP Cypher endpoint under-returns:
`MATCH (n:User {id:4062}) RETURN n` yields the string
`"http://example.org/user/4062"` instead of a node object with properties. Bolt on
the same server/commit returns the full node (labels + all properties + adjacency).

**Impact.** (1) Any HTTP client asking for whole nodes silently gets bare IRIs. (2)
It invalidated the HTTP baseline for node-shaped benchmark queries
(`neighbours_2_with_data*`) — those Fluree-HTTP numbers were artificially fast
(~1 ms doing almost no work) and are **excluded** from fair comparison. With them
excluded, Fluree-HTTP geo-mean is 1.109 ms (vs 1.111 including — negligible, only 2
of 35 queries).

**Ideal fix.** HTTP `RETURN <nodeVar>` should hydrate the node to a JSON object
(id/labels/properties), matching the Bolt `to_cypher_typed_table` path — the
converter already exists; the cypher-json surface just isn't using it for bare node
vars.
