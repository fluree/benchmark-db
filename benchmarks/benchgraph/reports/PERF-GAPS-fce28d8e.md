# Cypher perf gaps vs Neo4j/Memgraph — benchgraph Pokec (bug-style report)

For the db team. Fluree `fix/cypher-benchgraph-gaps` @ fce28d8e (35/35
functional). Numbers: Fluree = single-client warm median over HTTP,
r7a.4xlarge, this repo's runner. Neo4j 5.19 / Memgraph 2.16 = **their
published p50**, same instance type (r7a.4xlarge), hot condition, 12 Bolt
workers, from github.com/memgraph/benchgraph results/benchmarks.json
(vendored in ../upstream/benchgraph-published-results.json). Published data
covers pokec small (10k nodes/122k edges) + medium (100k/1.77M) only;
large (1.6M/30.6M) is Fluree-only.

Caveat on sub-ms rows: their numbers are Bolt round trips, ours include
HTTP+JSON envelope (~0.3–0.5 ms). Ratios ≤ ~4× on sub-ms queries are partly
transport; everything ≥ 10× is engine.

Repro for any query: see ../README.md (box setup) — data + queries in this
directory; all queries run verbatim via
`curl -X POST .../v1/fluree/query/pokec:main -H 'Content-Type: application/cypher'`.

---

## PERF-1 — Single-node property anchor does a label scan, not a seek

**Severity: critical — 1000× at medium, linear in |label|.**

```cypher
MATCH (n:User {id: $id}) RETURN n
```

| | Memgraph | Neo4j | Fluree | F/N |
|---|---|---|---|---|
| small | 0.15 | 0.22 | 21.1 | 96× |
| medium | 0.15 | 0.22 | 226.7 | **1032×** |
| large | — | — | 4,448 | (linear) |

**Evidence it's the plan, not the index:** the identical constraint used as
a join anchor is flat — `MATCH (s:User {id: $id})-->(n:User)` (expansion_1)
runs 1.9 / 2.5 / 3.5 ms at small/medium/large. The (p,o)→s resolution
exists and is fast; the standalone-node pattern doesn't use it. Write-side
WHERE got exactly this fix in fce28d8e (`update__vertex_on_property`:
`MATCH (n {id: $id}) SET …` = 2.4 ms at medium) — the read path needs the
same stats-driven anchor selection.

Affected queries: `single_vertex_read`, `vertex_on_label_property_index`,
`vertex_on_property`, `vertex_on_label_property` (4/35, incl. the
benchmark's flagship "index seek" row).

---

## PERF-2 — Fixed-hop expansion chains enumerate paths; DISTINCT endpoints need frontier BFS

**Severity: high — 17× at medium, >120 s timeouts on hub seeds at large.**

```cypher
MATCH (s:User {id: $id})-->()-->()-->()-->(n:User) RETURN DISTINCT n.id
```

| expansion_4 | Memgraph | Neo4j | Fluree | F/N |
|---|---|---|---|---|
| small | 74.3 | 104.5 | 346.4 | 3.3× |
| medium | 345.6 | 411.3 | 6,973 | **17×** |
| large | — | — | 14,426* | seed-dependent 74 ms – >120 s |

expansion_3: 98/581/1,183 ms (F/N 8.8× → 13.2×). expansion_2: 9.8/27/37 ms
(7.5× → 11.3×). \* median of successful runs; 3 runs timed out at 120 s.

**Hypothesis:** the chain of anonymous hops is executed as joins that
materialize every path (hub seeds ⇒ 10⁵–10⁷ paths), then DISTINCT at the
end. With `RETURN DISTINCT n.id` and no path/edge variables bound, the
query is semantically per-level reachability — a layered frontier BFS with
per-level dedup (the machinery the untyped var-length wildcard already
uses) bounds work by frontier size, not path count. The widening gap with
scale (3.3× → 17×) and the timeout tail are both path-count artifacts.

---

## PERF-3 — Whole-graph / label aggregates are full scans

**Severity: high — 22–30×, linear in graph size.**

```cypher
MATCH (n) RETURN count(n), count(n.age)          -- aggregation__count
MATCH (n) RETURN min(n.age), max(n.age), avg(n.age)
MATCH (n:User) RETURN n.age, COUNT(*)            -- GROUP BY variant
```

| | Memgraph | Neo4j | Fluree | F/N |
|---|---|---|---|---|
| count, small | 1.45 | 2.42 | 72.4 | 30× |
| count, medium | 12.6 | 22.2 | 610 | 27.5× |
| count, large | — | — | 11,928 | |
| min_max_avg, medium | 32.5 | 32.2 | 762 | 23.6× |
| GROUP BY age, medium | 16.1 | 22.7 | 92.3 | 4.1× |

**Notes:** `count(n)` over all subjects is answerable from index
statistics/metadata in O(1)-ish; per-predicate aggregates
(count/min/max/avg over one property) want a predicate-index (OPST) scan
rather than a whole-graph distinct-subject pass. Neo4j itself serves
count-store lookups for the count shapes — that's the 2.4 ms row. The
GROUP BY variant at 4× is respectable; the count/min-max shapes are not.

---

## PERF-4 — Bounded var-length `*1..k` has large result-independent overhead

**Severity: high at scale — 45–96× at medium, ~1.5 s flat at large.**

```cypher
MATCH (s:User {id: $id})-[*1..2]->(n:User) RETURN DISTINCT n.id
```

| | Memgraph | Neo4j | Fluree | F/N |
|---|---|---|---|---|
| small | 0.76 | 1.35 | 24.3 | 18× |
| medium | 1.09 | 2.51 | 111.7 | 44.6× |
| medium, with_filter | 0.81 | 1.72 | 166.2 | **96.5×** |
| large | — | — | 1,643 | |

**Smell:** at large, all four neighbours_2 variants sit at 1.53–1.64 s
whether they return 257 or 2,151 rows — cost is not result-driven. The
seed anchor is fast (PERF-1's join path), so the overhead is inside the
var-length execution (union-of-chains expansion?). Same frontier-BFS
machinery as PERF-2 applies; profile first to find the flat cost.

---

## PERF-5 — ~1 ms per-request floor (parse/plan/serialize/HTTP)

**Severity: moderate — caps every micro-query at ~4–12× vs sub-ms vendors.**

```cypher
MATCH (n:User {id: $id})-[e]->(m) RETURN m LIMIT 1   -- pattern_short
```

pattern_short: 0.94–1.02 ms at every size (Neo4j 0.23, Memgraph 0.16).
pattern_long 1.7–1.9 ms, pattern_cycle ~2.1 ms, expansion_1 1.9–3.5 ms,
update SET 2.0–2.5 ms. All flat across sizes — pure per-request cost.

~0.3–0.5 ms is HTTP-vs-Bolt transport (their p50s are Bolt); the remainder
is our parse→lower→plan→execute→serialize pipeline. Worth a flamegraph of
a pattern_short request: if plan construction or response envelope
building dominates, a prepared-statement/plan-cache path (queries are
$param-ized — cache key is the statement text) could take these near wire
floor. Matters because 12 of 35 benchmark queries are sub-ms for both
competitors, and it compounds every concurrency test.

---

## Non-bugs (already competitive)

| query | Memgraph | Neo4j | Fluree |
|---|---|---|---|
| single_vertex_write (medium) | 0.16 | 2.04 | **1.55 — beats Neo4j** |
| single_edge_write (medium) | 0.18 | 2.78 | **2.37 — beats Neo4j** |
| shortestPath / allShortestPaths (large) | not published | not published | 7.6 / 11.4 ms |

Priority order by benchmark impact: PERF-1 (4 queries, worst optics,
likely smallest fix) → PERF-2/PERF-4 (10 queries, shared frontier-BFS
machinery) → PERF-3 (3 queries) → PERF-5 (broad but bounded win).
