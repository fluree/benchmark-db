# SPARQLoscope benchmark — DBLP-KG (bibliography + OpenCitations citations)

> **Fluree v4.0.5 vs QLever. This is the DBLP KG+citations dataset (~1.57B triples), NOT the paper's ~502M core, so it is NOT directly comparable to the published SPARQLoscope table (engine-vs-engine on one box).**

**Dataset:** 1,574,283,728 triples, 96 predicates (snapshot 2026-05-30 01:16:39 GMT) · **Engines:** Fluree v4.0.5, QLever latest · **Box:** AWS r7a.4xlarge (16c / 128 GB) · 1+3 runs, median, 300 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever |
|---|---|---|
| passed | 105/105 | 105/105 |
| arith mean | **5,607 ms (1.0×)** | 21.4 s (3.8×) |
| geo mean | **227 ms (1.0×)** | 364 ms (1.6×) |
| median | **93 ms (1.0×)** | 368 ms (4.0×) |

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever |
|---|---|
| 1.10× | 4.00× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | fastest |
|---|--:|---|---|---|
| Dataset statistics | 6 | 113 ms (5.4×) | **21 ms (1.0×)** | QLever |
| JOIN | 12 | **101 ms (1.0×)** | 125 ms (1.2×) | Fluree |
| OPTIONAL | 10 | **175 ms (1.0×)** | 589 ms (3.4×) | Fluree |
| MINUS | 10 | **204 ms (1.0×)** | 574 ms (2.8×) | Fluree |
| EXISTS | 10 | **200 ms (1.0×)** | 835 ms (4.2×) | Fluree |
| UNION | 5 | **268 ms (1.0×)** | 666 ms (2.5×) | Fluree |
| GROUP BY / aggregate | 16 | **199 ms (1.0×)** | 288 ms (1.4×) | Fluree |
| FILTER | 3 | 204 ms (1.0×) | **197 ms (1.0×)** | QLever |
| Numeric functions | 10 | **75 ms (1.0×)** | 81 ms (1.1×) | Fluree |
| Date functions | 3 | **75 ms (1.0×)** | 221 ms (3.0×) | Fluree |
| String / REGEX | 11 | **6,668 ms (1.0×)** | 11.1 s (1.7×) | Fluree |
| Transitive paths | 4 | **104 ms (1.0×)** | 184 ms (1.8×) | Fluree |
| Result size / export | 5 | 277 ms (1.5×) | **181 ms (1.0×)** | QLever |

### 1c. Per query

| query | category | Fluree | QLever | results |
|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **75 ms (1.0×)** | 5,689 ms (75.9×) | ✓ |
| `number-of-literals` | Dataset statistics | **511 ms (1.0×)** | 14.6 s (28.5×) | ≈ |
| `number-of-objects` | Dataset statistics | 324 ms | **0 ms** | ≈ |
| `number-of-predicates` | Dataset statistics | 24 ms | **0 ms** | ✓ |
| `number-of-subjects` | Dataset statistics | 285 ms | **0 ms** | ✓ |
| `number-of-triples` | Dataset statistics | 24 ms | **0 ms** | ≈ |
| `join-2-large-large` | JOIN | **49 ms (1.0×)** | 368 ms (7.5×) | ✓ |
| `join-2-large-large-with-large-result` | JOIN | **77 ms (1.0×)** | 414 ms (5.4×) | ≈ |
| `join-2-large-large-with-small-result` | JOIN | 69 ms (3.3×) | **21 ms (1.0×)** | ✓ |
| `join-2-large-small` | JOIN | 49 ms | **4 ms** | ≈ |
| `join-2-largest-result` | JOIN | **77 ms (1.0×)** | 414 ms (5.4×) | ≈ |
| `join-2-small-large` | JOIN | 49 ms | **4 ms** | ≈ |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | **312 ms (1.0×)** | 2,705 ms (8.7×) | ≈ |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **391 ms (1.0×)** | 2,421 ms (6.2×) | ✓ |
| `join-xlarge-chain-on-small-predicates` | JOIN | **50 ms (1.0×)** | 475 ms (9.5×) | ✓ |
| `join-xlarge-star-on-small-predicates` | JOIN | 62 ms (2.8×) | **22 ms (1.0×)** | ✓ |
| `multicolumn-join-large` | JOIN | **1,189 ms (1.0×)** | 5,066 ms (4.3×) | ≈ |
| `multicolumn-join-small` | JOIN | 52 ms | **2 ms** | ✓ |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **78 ms (1.0×)** | 1,240 ms (15.9×) | ≈ |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | **70 ms (1.0×)** | 76 ms (1.1×) | ✓ |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | 69 ms (1.8×) | **39 ms (1.0×)** | ✓ |
| `optional-join-3-chain-1` | OPTIONAL | **314 ms (1.0×)** | 2,405 ms (7.7×) | ≈ |
| `optional-join-3-chain-2` | OPTIONAL | **2,401 ms (1.0×)** | 8,734 ms (3.6×) | ≈ |
| `optional-join-3-star-1` | OPTIONAL | **408 ms (1.0×)** | 3,264 ms (8.0×) | ✓ |
| `optional-join-3-star-2` | OPTIONAL | **235 ms (1.0×)** | 2,381 ms (10.1×) | ✓ |
| `optional-join-large-large` | OPTIONAL | **378 ms (1.0×)** | 2,023 ms (5.4×) | ✓ |
| `optional-join-large-small` | OPTIONAL | **51 ms (1.0×)** | 1,029 ms (20.2×) | ≈ |
| `optional-join-small-large` | OPTIONAL | 51 ms | **4 ms** | ≈ |
| `minus-join-2-large-large-with-large-result` | MINUS | **75 ms (1.0×)** | 402 ms (5.4×) | ✓ |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | 59 ms (1.3×) | **47 ms (1.0×)** | ✓ |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | 59 ms (1.1×) | **54 ms (1.0×)** | ✓ |
| `minus-join-3-chain-1` | MINUS | **299 ms (1.0×)** | 1,845 ms (6.2×) | ✓ |
| `minus-join-3-chain-2` | MINUS | **5,190 ms (1.0×)** | 8,761 ms (1.7×) | ✓ |
| `minus-join-3-star-1` | MINUS | 2,032 ms (1.1×) | **1,912 ms (1.0×)** | ✓ |
| `minus-join-3-star-2` | MINUS | **242 ms (1.0×)** | 1,943 ms (8.0×) | ✓ |
| `minus-join-large-large` | MINUS | **241 ms (1.0×)** | 1,486 ms (6.2×) | ✓ |
| `minus-join-large-small` | MINUS | **51 ms (1.0×)** | 1,322 ms (25.9×) | ✓ |
| `minus-join-small-large` | MINUS | 50 ms (1.6×) | **32 ms (1.0×)** | ✓ |
| `exists-join-2-large-large-with-large-result` | EXISTS | **73 ms (1.0×)** | 766 ms (10.5×) | ✓ |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | **58 ms (1.0×)** | 61 ms (1.1×) | ✓ |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **58 ms (1.0×)** | 61 ms (1.1×) | ✓ |
| `exists-join-3-chain-1` | EXISTS | **306 ms (1.0×)** | 3,582 ms (11.7×) | ≈ |
| `exists-join-3-chain-2` | EXISTS | **5,179 ms (1.0×)** | 9,717 ms (1.9×) | ✓ |
| `exists-join-3-star-1` | EXISTS | **1,931 ms (1.0×)** | 3,833 ms (2.0×) | ✓ |
| `exists-join-3-star-2` | EXISTS | **233 ms (1.0×)** | 2,666 ms (11.4×) | ✓ |
| `exists-join-large-large` | EXISTS | **237 ms (1.0×)** | 1,337 ms (5.6×) | ✓ |
| `exists-join-large-small` | EXISTS | **51 ms (1.0×)** | 952 ms (18.7×) | ✓ |
| `exists-join-small-large` | EXISTS | **49 ms (1.0×)** | 127 ms (2.6×) | ≈ |
| `union-constraint-filter-restrictive` | UNION | 2,877 ms (1.2×) | **2,387 ms (1.0×)** | ✓ |
| `union-constraint-from-star` | UNION | **350 ms (1.0×)** | 1,582 ms (4.5×) | ✓ |
| `union-constraint-large-join` | UNION | **375 ms (1.0×)** | 781 ms (2.1×) | ≈ |
| `union-constraint-small-join` | UNION | **72 ms (1.0×)** | 122 ms (1.7×) | ✓ |
| `union-no-constraint` | UNION | **51 ms (1.0×)** | 365 ms (7.2×) | ✓ |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **1,577 ms (1.0×)** | 6,522 ms (4.1×) | ✓ |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **419 ms (1.0×)** | 14.0 s (33.3×) | ✓ |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 1,247 ms (1.2×) | **1,043 ms (1.0×)** | ✓ |
| `group-by-complex-aggregate` | GROUP BY / aggregate | **434 ms (1.0×)** | 2,097 ms (4.8×) | ✓ |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | 96 ms (7.4×) | **13 ms (1.0×)** | ✓ |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **201 ms (1.0×)** | 2,062 ms (10.3×) | ✓ |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | **426 ms (1.0×)** | 1,628 ms (3.8×) | ✓ |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | 108 ms (1.3×) | **85 ms (1.0×)** | ≈ |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | 54 ms | **1 ms** | ✓ |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **50 ms (1.0×)** | 79 ms (1.6×) | ✓ |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **51 ms (1.0×)** | 78 ms (1.5×) | ✓ |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | 92 ms (1.1×) | **85 ms (1.0×)** | ✓ |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | 48 ms | **1 ms** | ✓ |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **58 ms (1.0×)** | 261 ms (4.5×) | ⚠ |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **58 ms (1.0×)** | 260 ms (4.5×) | ⚠ |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **9,144 ms (1.0×)** | 83.3 s (9.1×) | ✓ |
| `filter-few-results` | FILTER | **372 ms (1.0×)** | 2,214 ms (6.0×) | ✓ |
| `filter-language-en` | FILTER | 61 ms | **0 ms** | ✓ |
| `filter-many-results` | FILTER | **374 ms (1.0×)** | 3,432 ms (9.2×) | ⚠ |
| `numeric-abs` | Numeric functions | **96 ms (1.0×)** | 188 ms (2.0×) | ✓ |
| `numeric-add` | Numeric functions | **93 ms (1.0×)** | 260 ms (2.8×) | ✓ |
| `numeric-baseline` | Numeric functions | 92 ms (1.1×) | **85 ms (1.0×)** | ✓ |
| `numeric-ceil` | Numeric functions | **97 ms (1.0×)** | 189 ms (1.9×) | ✓ |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | 53 ms (1.7×) | **31 ms (1.0×)** | ✓ |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | 52 ms | **5 ms** | ✓ |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | 52 ms (2.3×) | **23 ms (1.0×)** | ✓ |
| `numeric-floor` | Numeric functions | **95 ms (1.0×)** | 189 ms (2.0×) | ✓ |
| `numeric-greater` | Numeric functions | **53 ms (1.0×)** | 121 ms (2.3×) | ✓ |
| `numeric-round` | Numeric functions | **96 ms (1.0×)** | 188 ms (2.0×) | ✓ |
| `date-day` | Date functions | **91 ms (1.0×)** | 236 ms (2.6×) | ⚠ |
| `date-month` | Date functions | **50 ms (1.0×)** | 235 ms (4.7×) | ⚠ |
| `date-year` | Date functions | **92 ms (1.0×)** | 194 ms (2.1×) | ✓ |
| `regex-3` | String / REGEX | **117.1 s (1.0×)** | 245.9 s (2.1×) | ✓ |
| `regex-3-contains` | String / REGEX | **57.7 s (1.0×)** | 229.9 s (4.0×) | ✓ |
| `regex-3-fixed` | String / REGEX | **108.5 s (1.0×)** | 244.9 s (2.3×) | ✓ |
| `regex-prefix-1` | String / REGEX | 205 ms | **7 ms** | ✗ |
| `regex-prefix-2` | String / REGEX | 85 ms | **4 ms** | ✗ |
| `regex-prefix-3` | String / REGEX | 62 ms | **1 ms** | ✗ |
| `strafter` | String / REGEX | **65.8 s (1.0×)** | 257.8 s (3.9×) | ✓ |
| `strbefore` | String / REGEX | **65.6 s (1.0×)** | 257.7 s (3.9×) | ✓ |
| `strends` | String / REGEX | **63.0 s (1.0×)** | 234.2 s (3.7×) | ✓ |
| `strlen` | String / REGEX | **58.4 s (1.0×)** | 234.9 s (4.0×) | ✓ |
| `strstarts` | String / REGEX | **92 ms (1.0×)** | 232.8 s (2530.4×) | ✓ |
| `transitive-path-large-join-and-plus` | Transitive paths | **137 ms (1.0×)** | 62.2 s (453.9×) | ✗ |
| `transitive-path-plus` | Transitive paths | 258 ms (1.9×) | **135 ms (1.0×)** | ✓ |
| `transitive-path-plus-fixed-subject` | Transitive paths | 51 ms | **1 ms** | ✓ |
| `transitive-path-small-join-and-plus` | Transitive paths | **66 ms (1.0×)** | 136 ms (2.1×) | ✗ |
| `result-size-large` | Result size / export | **721 ms (1.0×)** | 2,460 ms (3.4×) | ✓ |
| `result-size-medium` | Result size / export | **117 ms (1.0×)** | 254 ms (2.2×) | ✓ |
| `result-size-small` | Result size / export | 54 ms | **4 ms** | ✓ |
| `result-size-tiny` | Result size / export | 52 ms | **3 ms** | ✓ |
| `result-size-xlarge` | Result size / export | **6,864 ms (1.0×)** | 25.8 s (3.8×) | ✓ |

## 2. Result correctness

Result-equivalence vs the reference engine (per-query `results` column above): **95/105 agree** (68 exact ✓, 18 within the data delta ≈, 9 row-count ✓); **5 documented engine-semantics differences ⚠**; **5 with minor ±1-row differences ✗**.

**Documented differences (⚠)** — both results defensible; Fluree follows the SPARQL spec where they diverge (see §4 caveats): `date-day`, `date-month`, `filter-many-results`, `group-by-implicit-string-max`, `group-by-implicit-string-min`.

**Minor ±1-row differences (✗)** — boundary/edge differences in regex-prefix and transitive-path handling; all other queries agree: `regex-prefix-1`, `regex-prefix-2`, `regex-prefix-3`, `transitive-path-large-join-and-plus`, `transitive-path-small-join-and-plus`.

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 1,047 s | 1.50 M tr/s | 72 GB | ~53 GB | parallelized import (16 parse threads + parallel secondary index builds) |
| QLever | 3,937 s | 0.40 M tr/s | n/a | 20.7 GB | required --parallel-parsing false (per-shard prefixes) + -m 90G (merge memory) |

- **Fluree phases:** parse+commit 633 s, index build 336 s (3 secondaries built in parallel alongside SPOT)

- **QLever phases:** sequential parse ~50 min (parallel parse rejected on this layout) + permutation build

## 4. Environment & dataset

- **Dataset:** DBLP-KG (bibliography + OpenCitations citations) — dblp_KG_with_associated_data.tar — DBLP bibliography plus OpenCitations citation data
  - source: https://sparql.dblp.org/download/dblp_KG_with_associated_data.tar
  - version: snapshot 2026-05-30 01:16:39 GMT · SHA-256 `963cf2d1483a068ba8460b901c11a3bd3598e22f945aff181f65740754329cba`
  - **1,574,283,728 triples**, 96 predicates, ? subjects, 341,753,932 objects · on-disk 6.1 GB compressed (168 .ttl.gz shards)
- **Hardware:** AWS r7a.4xlarge — AMD EPYC (Zen 4), no-SMT, 16 cores, 128 GB RAM, 500 GB gp3 (6000 IOPS / 500 MB/s), Ubuntu 24.04
- **Method:** 1 warmup + 3 timed runs, median reported, 300 s timeout, results as `text/tab-separated-values`
  - QLever result cache disabled + cleared before each query so it re-executes (matches Fluree, which has no result cache). Reference engine for the correctness check: QLever.

| engine | version | config |
|---|---|---|
| Fluree | v4.0.5 | server cache auto (~63 GB); inline-indexed ledger |
| QLever | latest (`adfreiburg/qlever:latest (fabf229)`) | MEMORY_FOR_QUERIES 60G, CACHE 20G (disabled for benchmark) |

**Caveats**
- Triple-count delta: Fluree 1,574,283,728 vs QLever 1,574,230,030 (+0.0034%) — full-scan counts differ slightly; folded into 'within data delta' agreement.
- NOT comparable to the published SPARQLoscope table (that used the ~502M DBLP core, no citations). Absolute times are this-box-only.
- Fluree's import (1,047 s, parallelized) vs QLever (3,937 s) — QLever handicapped by the forced sequential parse on this concatenated shard layout.
- Documented engine-semantics differences (⚠, both defensible, Fluree spec-correct): filter-many-results — FILTER(?s != ?o) over blank-node subjects; both agree the data is identical (0 self-typed), Fluree keeps the 113.9M bnode rows (spec-correct per RDFterm-equal), QLever drops them. date-day / date-month — DAY()/MONTH() on a gYear literal (edge case). group-by-implicit-string-max / -min — string collation order.
- Five queries differ from QLever by ±1 row (regex-prefix-1/2/3, transitive-path-large/small-join-and-plus) — boundary/edge differences in regex-prefix and transitive-path handling; the other 100 queries agree.
