# benchgraph Pokec on AWS r7a.4xlarge — Fluree @ fce28d8e

First AWS run, 2026-07-05. Box: r7a.4xlarge (16 vCPU AMD / 128 GB — the same
instance type as Memgraph's current published benchgraph methodology),
us-east-1, Ubuntu 24.04, 150 GB gp3. Fluree built from
`fix/cypher-benchgraph-gaps` @ fce28d8e, release profile. Single-client HTTP
latency, 5 timed runs + 2 warmups, seed 42, 120 s timeout,
`FLUREE_CYPHER_ALLOW_FULL_SCAN=1`. Fresh ledger + fresh server per size.

## Imports

| size | vertices | edges | flakes | time | rate |
|---|---|---|---|---|---|
| small | 10,000 | 121,716 | 0.2M | 0.45s | 0.38 M/s |
| medium | 100,000 | 1,768,515 | 2.3M | 6.9s | 0.33 M/s |
| large | 1,632,803 | 30,622,564 | 38.8M | 143s | 0.27 M/s |

## Median latency (ms) per query per size

Pass rate: small 35/35, medium 35/35, large 35/35 queries but 3 individual
runs timed out at 120 s (expansion_4 run1, expansion_4_with_filter runs 4–5 —
seed-vertex dependent, see finding 1).

| query | small | medium | large | rows(large) |
|---|---|---|---|---|
| aggregation__count | 72.4 | 610.1 | 11,928 | 1 |
| aggregation__min_max_avg | 83.6 | 762.0 | 15,315 | 1 |
| arango__aggregate | 9.9 | 92.3 | 1,582 | 114 |
| arango__aggregate_with_distinct | 8.6 | 79.5 | 1,344 | 1 |
| arango__aggregate_with_filter | 12.5 | 123.0 | 2,589 | 95 |
| arango__allshortest_paths | 1.6 | 4.5 | 11.4 | 0 |
| arango__expansion_1 | 1.9 | 2.5 | 3.5 | 34 |
| arango__expansion_1_with_filter | 1.0 | 3.6 | 3.8 | 2 |
| arango__expansion_2 | 9.8 | 27.0 | 37.3 | 0 |
| arango__expansion_2_with_filter | 13.0 | 23.8 | 42.4 | 0 |
| arango__expansion_3 | 98.0 | 580.7 | 1,183 | 485 |
| arango__expansion_3_with_filter | 123.5 | 175.5 | 7,477 | 10,976 |
| arango__expansion_4 | 346.4 | 6,973 | 14,426* | 92,267 |
| arango__expansion_4_with_filter | 670.3 | 8,135 | 37,624* | 71,571 |
| arango__neighbours_2 | 24.3 | 111.7 | 1,643 | 2,151 |
| arango__neighbours_2_with_data | 16.5 | 181.5 | 1,530 | 269 |
| arango__neighbours_2_with_data_and_filter | 21.5 | 92.8 | 1,571 | 257 |
| arango__neighbours_2_with_filter | 14.9 | 166.2 | 1,576 | 519 |
| arango__shortest_path | 1.7 | 6.0 | 7.6 | 1 |
| arango__shortest_path_with_filter | 2.6 | 4.4 | 14.4 | 0 |
| arango__single_edge_write | 2.1 | 2.4 | 2.8 | 1 |
| arango__single_vertex_read | 21.1 | 226.7 | 4,448 | 1 |
| arango__single_vertex_write | 1.4 | 1.5 | 1.6 | 1 |
| arango__unwind_range_vertex_write | 9.0 | 8.9 | 9.0 | 1 |
| create__edge | 2.2 | 2.4 | 3.9 | 1 |
| create__pattern | 1.3 | 1.6 | 1.7 | 1 |
| create__vertex | 1.3 | 1.5 | 1.8 | 1 |
| create__vertex_big | 1.7 | 1.7 | 1.8 | 1 |
| match__pattern_cycle | 2.1 | 2.1 | 1.6 | 0 |
| match__pattern_long | 1.8 | 1.7 | 1.9 | 1 |
| match__pattern_short | 1.0 | 0.9 | 1.0 | 1 |
| match__vertex_on_label_property | 24.9 | 253.7 | 4,315 | 1 |
| match__vertex_on_label_property_index | 21.0 | 236.2 | 4,450 | 1 |
| match__vertex_on_property | 20.8 | 234.2 | 4,472 | 1 |
| update__vertex_on_property | 2.0 | 2.4 | 2.5 | 1 |

\* median of successful runs; distribution is seed-dependent (74 ms for a
sparse seed vertex to >120 s timeout for a hub).

Geo-mean (all 35): small 8.8 ms · medium 29.9 ms · large 116 ms.

## Optimization opportunities, ranked

1. **Single-node property anchor does a label scan, not a seek.**
   `MATCH (n:User {id: $id}) RETURN n` scales linearly with |User|:
   21 ms → 227 ms → 4,450 ms. The join-anchored identical constraint
   (`(s:User {id: $id})-->(n)`, expansion_1) stays flat at 1.9 → 2.5 →
   3.5 ms — the engine demonstrably CAN resolve {property: value} as a
   seek when the node participates in a join, but the standalone node
   pattern falls back to scan+filter. This is benchgraph's flagship
   "index seek" query (Neo4j: ~1 ms with its `:User(id)` index). Fixing
   the single-node plan to use the same (p,o)→s path as the join case
   affects 4 of 35 queries and is the single most visible number.

2. **Fixed-length expansion chains enumerate paths; DISTINCT endpoints
   want frontier BFS.** expansion_4 medians 14.4 s (large), with runs
   >120 s from hub seeds; expansion_3 1.2–7.5 s. The pattern
   `-->()-->()-->()-->(n:User) RETURN DISTINCT n.id` enumerates every
   4-hop path (10^4–10^6+ for hubs) then dedups. A planner rewrite to
   layered frontier expansion with per-level dedup (the machinery the
   untyped var-length BFS already has) makes cost proportional to
   frontier sizes, not path counts. Memgraph's own headline win over
   Neo4j is exactly this query group.

3. **Whole-graph / label-scan aggregations.** `count(n), count(n.age)`
   11.9 s; `min/max/avg(n.age)` 15.3 s on large. All scale linearly.
   count(n) could come from index statistics; single-predicate
   aggregates (count/min/max/avg over one property) could run as a
   predicate-index (OPST) scan or from column stats instead of a
   whole-graph distinct-subject pass. Label-scan GROUP BY
   (`arango__aggregate`, 1.6 s for 1.6M values) is ~1M values/s —
   plausibly several-fold headroom in a tighter aggregation path.

4. **Bounded var-length `*1..2` sits ~1.5–1.6 s on large regardless of
   result size** (269–2,151 rows). Medium is 92–182 ms. The flat cost
   across variants suggests a fixed overhead in the union-of-chains
   execution rather than result-driven work. Profile-worthy.

5. **Import rate declines with size** (0.38 → 0.27 M flakes/s) and is
   ~3-4× below the dblp-core rates on comparable hardware. Not a query
   issue; noting for completeness.

## What's already strong

- **Writes: flat ~1.4–2.8 ms at every size** — create__edge at 1.6M
  users is 2.8 ms (was 360 ms before fce28d8e's stats-driven write
  planning). UNWIND batch of 100 nodes: 9 ms flat.
- **shortestPath/allShortestPaths: 7.6 / 11.4 ms on large** —
  bidirectional BFS scales beautifully (Memgraph's published Neo4j
  numbers for this group are hundreds of ms on small).
- **pattern_cycle/long/short: ~1–2 ms flat** — LIMIT-1 early exit works.
- **expansion_1/2: flat across sizes** (3.5 / 37 ms at large).

## Vs Memgraph's CURRENT published numbers (same instance type!)

The benchgraph site's data is public JSON
(github.com/memgraph/benchgraph → results/benchmarks.json, vendored in
upstream/benchgraph-published-results.json): Memgraph v2.16 vs Neo4j 5.19,
July 2024, on r7i/r7a.4xlarge — the same instance type as this run. They
publish pokec **small and medium only** (no large), isolated/mixed
workloads, cold/hot/vulcanic, 12/24/48 Bolt workers.

Comparison below: their AMD / hot / 12-worker isolated **p50** vs our
single-client warm **median** — closest available match-up, still not
identical (their p50 is under 12-way concurrency via Bolt; ours has HTTP
envelope overhead of roughly 0.3–0.5 ms that dominates sub-ms rows).

Geo-mean over the 23 overlapping queries:

| | Memgraph | Neo4j | Fluree | F/N ratio |
|---|---|---|---|---|
| pokec small | 0.94 ms | 1.70 ms | 12.86 ms | 7.6× |
| pokec medium | 1.95 ms | 3.57 ms | 47.54 ms | 13.3× |

Where the gap lives (medium, Fluree ÷ Neo4j 5.19 p50):

| group | ratio | driver |
|---|---|---|
| single_vertex_read | **1032×** (0.22 → 227 ms) | finding 1: label scan not seek |
| neighbours_2 group | 38–96× | finding 4 + scan overheads |
| aggregate_count / min_max_avg | 24–28× | finding 3: whole-graph scans |
| expansion_1–4 | 6–17× | finding 2: path enumeration |
| aggregate (GROUP BY) | 4–4.5× | tighter agg path wanted |
| pattern_* / property update | 4–12× | ~1 ms fixed floor (see below) |
| **single_vertex_write / single_edge_write** | **0.8–0.9× — Fluree FASTER than Neo4j** | fce28d8e write path |

Notes:
- Both vendors' fast queries sit at 0.15–0.35 ms p50; our floor is
  ~0.9–1 ms even for LIMIT-1 patterns. A chunk of that is HTTP+JSON
  round-trip vs Bolt; per-request overhead (parse/plan/serialize) is a
  legitimate optimization surface for sub-ms parity.
- Fluree beats Neo4j on both write micro-queries (Neo4j p50 2.0–2.9 ms).
  Memgraph's in-memory writes (0.16–0.18 ms) are a different storage
  contract (see their durability trade-offs).
- Their large-size numbers don't exist, so our large results stand alone
  until we co-measure Neo4j on this box.

## Repro

```
benchmarks/benchgraph/bootstrap-box.sh   # box setup (deps, build, datasets)
benchmarks/benchgraph/run-box.sh         # per-size import + suite
results in results/aws-r7a4xl/{small,medium,large}.tsv
```
