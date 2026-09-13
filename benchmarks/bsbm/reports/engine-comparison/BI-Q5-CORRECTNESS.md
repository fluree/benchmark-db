# Virtuoso BI Q5 correctness note

Validation on 2026-09-08 reproduced incorrect empty results in **Virtuoso 7.2.17**
for canonical BSBM BI Q5. All **151 product types** in the pinned 1M input should
produce nonempty results; Virtuoso returned zero rows for each. Fluree 4.2.0
matched an independent RDF-input calculation of result membership, review counts,
and average prices for all 151 types. Ordering and literal datatype serialization
were not validated by this check.

The six exact qualification queries should return 15, 16, 16, 23, 19, and 15 rows
(mean 17.33), matching Fluree's recorded result counts. Virtuoso returned zero.

## Minimal reproduction

This query requires no loaded data:

```sparql
SELECT ?country ?product ?avgPrice WHERE {
  VALUES (?country ?product) { (<urn:country> <urn:product>) }
  {
    SELECT ?country ?product (AVG(?price) AS ?avgPrice)
    WHERE {
      VALUES (?product ?price) { (<urn:product> 1) (<urn:product> 3) }
    }
    GROUP BY ?country ?product
  }
}
```

Expected: one row, `urn:country`, `urn:product`, `2`. Fluree 4.2.0 and RDFLib 7.5.0
return that row; Virtuoso 7.2.17 returns none. Virtuoso returns a row for the grouped
subquery alone. Removing its unused `?country` from SELECT and GROUP BY restores
the outer join in a diagnostic control. This isolates the failing pattern to a
join involving an unbound grouping variable; it does not establish the internal
implementation cause. SPARQL's [join semantics](https://www.w3.org/TR/sparql11-query/#defn_algJoin)
require agreement only on variables bound on both sides.

The canonical benchmark query is unchanged. Virtuoso's BI totals affected by this
failure must not be presented as equivalent-work throughput. This finding does
not invalidate Explore or Update results, which use different queries.

## Scope and evidence

The 7.2.17 validation used the same pinned Linux release archive as the September
refresh, in an isolated local container with a smaller memory profile. These are
correctness checks, not replacement performance measurements. The June tables
use Virtuoso 7.2.5 and already record empty Q5 results; the reduced reproduction
above was tested on 7.2.17.

Input: 724,101 statements, SHA256
`0eca9f19829be6390700196c5de4fe6e3d0610e1cd09d7f780de6526a95a48c8`.
The [investigation record](../../../../runs/bsbm-validation-20260908/REPORT.md)
documents the oracle, scripts, raw responses, binary identity, and retained
diagnostic database.
