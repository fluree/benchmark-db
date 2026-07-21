# Fluree Cypher gaps vs Memgraph benchgraph (Pokec)

> **STATUS UPDATE 2026-07-05: ALL GAPS CLOSED — 35/35 verbatim.**
> Branch `fix/cypher-benchgraph-gaps`:
> - @ 9e72f0499 closed B1, B2, D1, F2, F3 (behind
>   `FLUREE_CYPHER_ALLOW_FULL_SCAN=1`), F4, F5 → 33/35, verified against
>   dataset ground truth (expansion counts exact; pattern_* return correct
>   rel values; untyped shortestPath paths correct; bare-scan counts
>   correct).
> - @ fce28d8e closed F1 (write RETURN — returns the created entity ids
>   as a cypher-json rowset) and N2 (stats-driven write-side WHERE
>   planning: create__edge **360ms → 1.4ms**; all write queries now
>   1.1–1.7ms) → **35/35, zero failures** (results/fix_fce28d8.tsv).
>
> The analysis below documents the original d55861508 state.

Triage from the first full runs of the Neo4j-portable Pokec query set against
Fluree (db @ d55861508, debug + release builds — identical failure sets;
pokec_small: 10k users / 121,716 Friend edges, plain-triple import,
zero-config ledger → `http://example.org/` vocab). All queries execute
through the Cypher surface (`Content-Type: application/cypher` →
`fluree-db-cypher` parser); no SPARQL is involved at query time.

Release-build medians (5 runs, seed 42) for context: point lookup ~4ms,
full-label aggregates ~6-8ms, expansion_1 ~1ms, expansion_2 ~13ms,
expansion_3 ~69ms, expansion_4_with_filter ~493ms (5k rows),
neighbours_2 ~8-14ms. Perf smell: `create__edge`
(`MATCH (a),(b) CREATE (a)-[:TempEdge]->(b)`) is ~341ms vs ~1.2ms for a
standalone CREATE — the write-side anchored MATCH looks like it scans.

**Result: 24/35 queries pass, 11 fail.** Failures group into 5 missing
features and 2 bugs; plus 1 semantic divergence that makes 3 "passing"
queries return 0 rows.

Repro for any of these:

```bash
curl -s -X POST http://localhost:8090/v1/fluree/query/pokec:main \
  -H 'Content-Type: application/cypher' \
  --data '{"cypher": "<query>", "params": {"id": 4112}}'
# writes: same envelope against /v1/fluree/update/pokec:main
```

## Bugs

### B1. Untyped single-hop `-->` / `-[e]->` traverses `rdf:type`

`MATCH (n:User {id: 4112})-->(m) RETURN m LIMIT 1` returns
`http://example.org/User` — the **class node** — as a neighbor. Cypher `-->`
must only follow relationships, never labels. The untyped *var-length*
wildcard (`-[*1..2]->`) already excludes `rdf:type`, the reifier bundle, and
data properties; single-hop untyped should use the same edge-set definition.

Benchmark impact: `match__pattern_short`/`pattern_long`/`pattern_cycle` have
label-less targets, so their results are wrong (masked today by the 0-row
divergence D1 below). The `expansion_*` queries stay correct only because
their target `(n:User)` label filters the class node back out — the engine
still wastes work enumerating type/data edges at every unconstrained hop.

### B2. `SET n.property = -1` rejected — unary minus not folded to a literal

`MATCH (n {id: $id}) SET n.property = -1` →
"CREATE property values must be literals or bound variables in v1".
`SET n.property = 1` works. A negative number literal is `-` applied to a
literal in the AST; write-side lowering should const-fold it.

Fails: `update__vertex_on_property` (1 of the 8 write queries).

## Missing features (benchmark blockers)

### F1. RETURN on a write statement — 2 queries

`CREATE (n:UserTemp {id: $id}) RETURN n` and
`MATCH … CREATE (n)-[e:Temp]->(m) RETURN e` →
"RETURN on a write statement is deferred in v1".
Neo4j returns the created entities; benchgraph measures that round trip.
Fails: `arango__single_vertex_write`, `arango__single_edge_write`.

### F2. Untyped shortestPath / allShortestPaths — 3 queries

`shortestPath((n)-[*..15]->(m))` →
"shortestPath needs exactly one relationship type; untyped and alternation
forms are deferred". The typed forms (`-[:Friend*..15]->`) work and return
correct paths, so the BFS machinery is there — the untyped form just needs
the same wildcard edge-set the untyped var-length path already uses.
Fails: `arango__shortest_path`, `arango__shortest_path_with_filter`,
`arango__allshortest_paths`.

### F3. Bare `MATCH (n)` (whole-graph scan) — 2 queries

`MATCH (n) RETURN count(n), count(n.age)` → rejected by design ("a node must
be constrained by a label, a property, or a relationship"). Reasonable guard
for production; benchmarks and ad-hoc exploration want it. Suggest an opt-in
(server flag or query option) rather than a rewrite, so the benchmark runs
verbatim. Fails: `aggregation__count`, `aggregation__min_max_avg`.

### F4. Bare `()` node in CREATE — 2 queries

`CREATE ()` and `CREATE ()-[:TempEdge]->()` → "every node needs a variable,
a label, or a property". An anonymous propertyless node is representable
(a subject with no triples needs at least one; Neo4j nodes always have
internal identity). Could mint an IRI and assert nothing — or a marker
triple. Fails: `create__vertex`, `create__pattern`.

### F5. UNWIND before a write clause — 1 query

`UNWIND range(1, 100) as x CREATE (:L1:…:L7 {…})` → "UNWIND before a write
clause is deferred — supply the rows as a `$param` list of maps". The
$param desugar exists; this is the inline/range() variant.
Fails: `arango__unwind_range_vertex_write`.

## Semantic divergence (queries "pass" but return 0 rows)

### D1. Bound relationship variable sees only reifier-bundled edges

`match__pattern_cycle`, `pattern_long`, `pattern_short` bind edge variables
(`-[e1]->`) and return 0 rows against plain-triple data — documented
behavior (bag semantics requires a reifier identity). But benchgraph never
touches edge properties: it binds `e` only to *return* it. Options, best
first:

1. **Engine**: when a bound rel var has no property constraints, fall back to
   the plain triple and synthesize the `{start, type, end}` rel value from
   the base edge. Preserves LPG parity on RDF-imported data — pattern_cycle
   would then behave exactly like Neo4j.
2. **Import**: write reifier bundles for all 121k/30M edges — storage +
   import cost Neo4j doesn't pay; unfair to Fluree.
3. **Queries**: fluree-vendor branch dropping the rel vars — diverges from
   the published query texts (benchgraph does allow per-vendor branches).

## Observation (not a failure)

### N1. `RETURN n` serializes as the IRI string, not a property map

Neo4j's HTTP row format expands a returned node to its full property map;
Fluree's cypher-json returns the IRI string with `meta: null`. Four queries
(`single_vertex_read`, `vertex_on_label_property*`, `neighbours_2_with_data*`)
exist partly to measure node-serialization cost, so Fluree returns
structurally less data per row. For a published comparison either return
property maps for nodes (rich cypher-json is noted as deferred in the
support matrix) or rewrite the fluree branch as `RETURN properties(n)`
(already supported) to keep the measured work honest.

### N2. `create__edge` latency — anchored write-side MATCH looks like it scans

`MATCH (a:User {id: $from}), (b:User {id: $to}) CREATE (a)-[:TempEdge]->(b)`
runs ~340-360ms (both main and the fix branch), vs ~1.2ms for a standalone
CREATE and ~4ms for the *read-side* `MATCH (n:User {id: $id})`. The
write-side match appears to scan rather than seek. This is the benchmark's
`single_edge_write` / `create.edge` hot path (also used in the mixed/
realistic workloads), so it's worth a look before any published run.

## Not needed

None of Fluree's other deferred Cypher features (FOREACH, CALL procedures,
LOAD CSV, temporal constructors, multi-statement, …) are exercised by this
benchmark.

## Scoreboard

| Fix | Queries unblocked | Total passing |
|---|---|---|
| (today) | — | 24/35 |
| B2 unary minus | +1 | 25 |
| F1 write RETURN | +2 | 27 |
| F2 untyped shortestPath | +3 | 30 |
| F3 bare MATCH (n) | +2 | 32 |
| F4 bare CREATE () | +2 | 34 |
| F5 inline UNWIND write | +1 | 35/35 |
| B1 rdf:type in `-->` + D1 rel-var fallback | correctness of pattern_* | 35/35 correct |
