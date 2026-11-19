# SPARQLoscope benchmark — Wikidata Truthy

> **Fluree v4.2.8 measured 2026-11-19 (queries on the ledger imported 2026-11-12); QLever, Virtuoso and MillenniumDB measured 2026-06-10..12; Apache Jena measured 2026-06-05 with whole-second timing precision (its ~32 h load made a re-run impractical). Each engine ran on its own AWS r7a.16xlarge of the same specification. Fluree v4.2.8: 105/105 completed with no timeouts -- the only engine to answer all 105. Passed: Fluree 105/105, QLever 91/105, Virtuoso 81/105 (cost-estimation gate disabled; loaded 8.168B with wktLiteral pre-filtered), MillenniumDB 67/105 (full load), Apache Jena 31/105 (whole-second timings). Blazegraph EXCLUDED (silently drops blank nodes; at its scale ceiling at 8B). 105 queries, 1 warmup + 3 runs, 300s timeout (early-abort), fractional-ms timings via curl %{time_total}. Engine-vs-engine on this hardware specification only; not comparable to the paper's 2025-04-18 snapshot.**

**Dataset:** 8,180,602,084 triples, 13,306 predicates (snapshot 2026-05-29 11:17:24 GMT (rolling latest; pinned as GitHub release wikidata-truthy-source-20260529). Paper used 'as of 2025-04-18', no longer on the live mirror.) · **Engines:** Fluree v4.2.8, QLever latest, Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0, Apache Jena (TDB2/Fuseki) 6.1.0 · **Box:** AWS r7a.16xlarge (64c / 512 GB) · 1+3 runs, median, 300 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Virtuoso | MillenniumDB | Apache Jena (TDB2/Fuseki) |
|---|---|---|---|---|---|
| passed | 105/105 | 91/105 | 81/105 | 67/105 | 31/105 |
| geo mean (P=2) | **270.9 ms (1.0×)** | 3,833.3 ms (14.1×) | 12.9 s (47.6×) | 28.7 s (105.9×) | 151.5 s (559.2×) |
| geo mean (P=10) | **270.9 ms (1.0×)** | 4,750.8 ms (17.5×) | 18.6 s (68.8×) | 51.4 s (189.5×) | 471.0 s (1738.5×) |
| geo mean (passed only) | **270.9 ms (1.0×)** | 1,761.8 ms (6.5×) | 4,134.7 ms (15.3×) | 5,112.1 ms (18.9×) | 5,668.9 ms (20.9×) |
| arith mean (passed only) | **4,441.4 ms (1.0×)** | 18.3 s (4.1×) | 51.1 s (11.5×) | 59.4 s (13.4×) | 75.3 s (16.9×) |
| median (passed only) | **823.6 ms (1.0×)** | 2,796.2 ms (3.4×) | 9,147.3 ms (11.1×) | 10.3 s (12.5×) | 118.3 s (143.7×) |

_geo mean (P=2/P=10) is the SPARQLoscope paper's official aggregate: a failed or timed-out query counts as 2× / 10× the 300 s timeout. The passed-only rows average each engine's completed queries only, so they flatter engines with many failures._

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Virtuoso | MillenniumDB | Apache Jena (TDB2/Fuseki) |
|---|---|---|---|---|
| 1.29× | 8.04× | 17.32× | 30.26× | 66.25× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Virtuoso | MillenniumDB | Apache Jena (TDB2/Fuseki) | fastest |
|---|--:|---|---|---|---|---|---|
| Dataset statistics | 6 | 20.4 ms (1.6×) | **12.7 ms (1.0×)** | 2,177.9 ms (171.7×) | 208.4 s (16427.3×) | — | QLever |
| JOIN | 12 | 200.5 ms (2.1×) | 2,648.2 ms (27.6×) | 773.0 ms (8.1×) | **95.9 ms (1.0×)** | 496.6 ms (5.2×) | MillenniumDB |
| OPTIONAL | 10 | 380.9 ms (11.2×) | 11.0 s (323.4×) | 2,901.8 ms (85.3×) | 11.2 s (330.5×) | **34.0 ms (1.0×)** | Apache Jena (TDB2/Fuseki) |
| MINUS | 10 | **433.2 ms (1.0×)** | 10.1 s (23.4×) | 3,918.7 ms (9.0×) | 12.7 s (29.3×) | — | Fluree |
| EXISTS | 10 | 443.8 ms | 16.6 s | 530.2 ms | 14.6 s | **9.00 ms** | Apache Jena (TDB2/Fuseki) |
| UNION | 5 | **455.5 ms (1.0×)** | 9,543.0 ms (20.9×) | 14.8 s (32.4×) | 106.9 s (234.7×) | — | Fluree |
| GROUP BY / aggregate | 16 | **81.3 ms (1.0×)** | 835.7 ms (10.3×) | 3,912.3 ms (48.1×) | 5,090.8 ms (62.7×) | 43.4 s (534.1×) | Fluree |
| FILTER | 3 | 2,067.1 ms (1.3×) | **1,546.5 ms (1.0×)** | 48.0 s (31.0×) | 107.6 s (69.6×) | — | QLever |
| Numeric functions | 10 | **98.7 ms (1.0×)** | 1,337.1 ms (13.5×) | 4,340.1 ms (44.0×) | 4,017.6 ms (40.7×) | 128.3 s (1299.2×) | Fluree |
| Date functions | 3 | 3,775.3 ms (1.5×) | 3,386.2 ms (1.4×) | **2,461.5 ms (1.0×)** | 10.3 s (4.2×) | 119.2 s (48.4×) | Virtuoso |
| String / REGEX | 11 | 3,671.6 ms (67.9×) | **54.1 ms (1.0×)** | 221.3 s (4093.1×) | 246.8 s (4564.9×) | — | QLever |
| Transitive paths | 4 | **81.2 ms (1.0×)** | 99.2 ms (1.2×) | — | 329.9 ms (4.1×) | 1,087.9 ms (13.4×) | Fluree |
| Result size / export | 5 | 99.8 ms (1.2×) | 592.0 ms (7.1×) | 247.4 ms (3.0×) | **83.5 ms (1.0×)** | 312.2 ms (3.7×) | MillenniumDB |

### 1c. Per query

| query | category | Fluree | QLever | Virtuoso | MillenniumDB | Apache Jena (TDB2/Fuseki) |
|---|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **1.29 ms** | 17.3 ms | 6.41 ms | 180.0 s | — |
| `number-of-literals` | Dataset statistics | **8,579.1 ms (1.0×)** | 148.4 s (17.3×) | 71.7 s (8.4×) | 250.0 s (29.1×) | — |
| `number-of-objects` | Dataset statistics | 539.3 ms | **1.16 ms** | — | — | — |
| `number-of-predicates` | Dataset statistics | 2.24 ms | **1.07 ms** | — | — | — |
| `number-of-subjects` | Dataset statistics | 5.95 ms | **1.12 ms** | — | — | — |
| `number-of-triples` | Dataset statistics | **0.90 ms** | 1.16 ms | 22.5 s | 201.1 s | — |
| `join-2-large-large` | JOIN | **872.2 ms (1.0×)** | 23.8 s (27.3×) | 156.5 s (179.4×) | — | — |
| `join-2-large-large-with-large-result` | JOIN | **714.2 ms (1.0×)** | 12.6 s (17.7×) | 138.4 s (193.7×) | 163.0 s (228.2×) | — |
| `join-2-large-large-with-small-result` | JOIN | **61.5 ms (1.0×)** | 560.3 ms (9.1×) | 527.9 ms (8.6×) | 7,664.5 ms (124.7×) | 149.7 s (2434.9×) |
| `join-2-large-small` | JOIN | 5.84 ms | 55.3 ms | **4.36 ms** | 8.70 ms | — |
| `join-2-largest-result` | JOIN | **397.1 ms (1.0×)** | 16.6 s (41.7×) | 243.7 s (613.6×) | — | — |
| `join-2-small-large` | JOIN | 5.34 ms | 53.0 ms | **4.24 ms** | 16.8 ms | 30.0 ms |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | 26.5 s (1.4×) | **18.4 s (1.0×)** | — | — | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **1,925.0 ms (1.0×)** | 23.1 s (12.0×) | 22.8 s (11.8×) | — | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | 1.42 ms | 841.4 ms | **0.76 ms** | 1.61 ms | 7.00 ms |
| `join-xlarge-star-on-small-predicates` | JOIN | 1.79 ms | 90.3 ms | **0.75 ms** | 1.40 ms | 10.0 ms |
| `multicolumn-join-large` | JOIN | **20.4 s (1.0×)** | 116.0 s (5.7×) | 52.5 s (2.6×) | — | — |
| `multicolumn-join-small` | JOIN | 3,358.3 ms (18.4×) | 3,865.1 ms (21.2×) | 1,677.3 ms (9.2×) | **182.4 ms (1.0×)** | 96.1 s (526.9×) |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **730.0 ms (1.0×)** | 64.8 s (88.8×) | — | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | **106.6 ms (1.0×)** | 1,674.1 ms (15.7×) | 615.5 ms (5.8×) | 76.1 s (713.9×) | — |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | **66.5 ms (1.0×)** | 1,654.4 ms (24.9×) | 861.9 ms (13.0×) | 75.4 s (1134.6×) | — |
| `optional-join-3-chain-1` | OPTIONAL | 26.7 s (1.4×) | **19.4 s (1.0×)** | — | — | — |
| `optional-join-3-chain-2` | OPTIONAL | **25.4 s (1.0×)** | — | — | — | — |
| `optional-join-3-star-1` | OPTIONAL | **1,794.2 ms (1.0×)** | 111.6 s (62.2×) | 49.6 s (27.7×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **1,817.8 ms (1.0×)** | 78.6 s (43.3×) | 70.4 s (38.7×) | 200.0 s (110.0×) | — |
| `optional-join-large-large` | OPTIONAL | **884.3 ms (1.0×)** | 79.5 s (89.9×) | — | — | — |
| `optional-join-large-small` | OPTIONAL | **1.15 ms** | 18.7 s | 64.1 s | — | — |
| `optional-join-small-large` | OPTIONAL | 5.53 ms | 51.7 ms | **5.03 ms** | 13.9 ms | 34.0 ms |
| `minus-join-2-large-large-with-large-result` | MINUS | **680.8 ms (1.0×)** | 28.0 s (41.1×) | — | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | **50.7 ms (1.0×)** | 614.4 ms (12.1×) | 587.2 ms (11.6×) | 75.8 s (1494.4×) | — |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **54.0 ms (1.0×)** | 728.3 ms (13.5×) | 823.7 ms (15.2×) | 75.0 s (1388.7×) | — |
| `minus-join-3-chain-1` | MINUS | 17.0 s (1.1×) | **15.2 s (1.0×)** | 116.1 s (7.7×) | 108.1 s (7.1×) | — |
| `minus-join-3-chain-2` | MINUS | **19.9 s (1.0×)** | — | — | — | — |
| `minus-join-3-star-1` | MINUS | **11.5 s (1.0×)** | 85.6 s (7.5×) | 29.4 s (2.6×) | — | — |
| `minus-join-3-star-2` | MINUS | **1,389.6 ms (1.0×)** | 57.3 s (41.3×) | 23.7 s (17.0×) | 119.2 s (85.8×) | — |
| `minus-join-large-large` | MINUS | **823.6 ms (1.0×)** | 27.4 s (33.2×) | — | — | — |
| `minus-join-large-small` | MINUS | **5.24 ms** | 27.6 s | 63.2 s | — | — |
| `minus-join-small-large` | MINUS | 5.39 ms | 1,595.6 ms | 5.75 ms | **4.49 ms** | — |
| `exists-join-2-large-large-with-large-result` | EXISTS | **684.8 ms (1.0×)** | 48.5 s (70.8×) | — | — | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | **51.3 ms (1.0×)** | 1,101.3 ms (21.5×) | 593.1 ms (11.6×) | 75.1 s (1463.1×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **53.7 ms (1.0×)** | 957.0 ms (17.8×) | 798.8 ms (14.9×) | 72.2 s (1342.9×) | — |
| `exists-join-3-chain-1` | EXISTS | **17.6 s (1.0×)** | 26.7 s (1.5×) | 116.3 s (6.6×) | 113.9 s (6.5×) | — |
| `exists-join-3-chain-2` | EXISTS | **21.7 s (1.0×)** | — | — | — | — |
| `exists-join-3-star-1` | EXISTS | **12.5 s (1.0×)** | 26.2 s (2.1×) | — | — | — |
| `exists-join-3-star-2` | EXISTS | **1,405.7 ms (1.0×)** | 94.6 s (67.3×) | 20.8 s (14.8×) | 130.5 s (92.8×) | — |
| `exists-join-large-large` | EXISTS | **827.6 ms (1.0×)** | 66.2 s (80.0×) | — | — | — |
| `exists-join-large-small` | EXISTS | 5.37 ms | 26.7 s | **4.53 ms** | — | — |
| `exists-join-small-large` | EXISTS | 5.25 ms | 16.3 s | **4.29 ms** | 8.16 ms | 9.00 ms |
| `union-constraint-filter-restrictive` | UNION | 28.2 s (6.9×) | 33.4 s (8.2×) | **4,074.9 ms (1.0×)** | 105.7 s (25.9×) | — |
| `union-constraint-from-star` | UNION | **1,863.3 ms (1.0×)** | 19.9 s (10.7×) | 31.3 s (16.8×) | 196.6 s (105.5×) | — |
| `union-constraint-large-join` | UNION | **961.5 ms (1.0×)** | 16.1 s (16.7×) | 146.9 s (152.8×) | 208.8 s (217.2×) | — |
| `union-constraint-small-join` | UNION | **340.0 ms (1.0×)** | 3,053.2 ms (9.0×) | 1,822.7 ms (5.4×) | 29.2 s (85.9×) | — |
| `union-no-constraint` | UNION | **1.14 ms** | 2,436.7 ms | 20.4 s | 110.2 s | — |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **1.07 ms** | 26.5 ms | 97.0 ms | 86.4 ms | 216.0 ms |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **1.52 ms** | — | — | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 15.5 s (2.0×) | **7,595.2 ms (1.0×)** | 10.1 s (1.3×) | 12.8 s (1.7×) | — |
| `group-by-complex-aggregate` | GROUP BY / aggregate | 17.8 s (1.6×) | **11.5 s (1.0×)** | 88.9 s (7.7×) | — | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | **1.09 ms** | 2.56 ms | 17.9 ms | 33.5 ms | — |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **3,604.2 ms (1.0×)** | 52.6 s (14.6×) | — | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | 17.8 s (20.3×) | 9,744.1 ms (11.1×) | **878.7 ms (1.0×)** | 13.3 s (15.2×) | — |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | 1,584.2 ms (1.3×) | **1,203.9 ms (1.0×)** | 13.4 s (11.2×) | 3,673.5 ms (3.1×) | 126.6 s (105.2×) |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | **1.01 ms** | 2.46 ms | 891.8 ms | 3,294.2 ms | 121.9 s |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **1.59 ms** | 1,106.9 ms | 4,519.0 ms | 3,740.4 ms | 127.4 s |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **1.61 ms** | 1,134.2 ms | 2,892.7 ms | 3,810.4 ms | 125.9 s |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | 1,613.7 ms (1.3×) | **1,200.8 ms (1.0×)** | 9,095.2 ms (7.6×) | 3,638.9 ms (3.0×) | 124.8 s (103.9×) |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | **1.10 ms** | 6.73 ms | 9,811.8 ms | 89.2 s | — |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **92.4 ms (1.0×)** | 29.5 s (318.8×) | 62.1 s (672.1×) | 103.5 s (1119.5×) | — |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **92.7 ms (1.0×)** | 30.1 s (324.4×) | 42.5 s (458.6×) | 105.6 s (1139.8×) | — |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **1,828.0 ms (1.0×)** | — | — | — | — |
| `filter-few-results` | FILTER | **1,760.3 ms (1.0×)** | 27.5 s (15.6×) | 47.7 s (27.1×) | 87.1 s (49.5×) | — |
| `filter-language-en` | FILTER | 2,833.4 ms | **2.71 ms** | — | — | — |
| `filter-many-results` | FILTER | **1,770.8 ms (1.0×)** | 49.6 s (28.0×) | 48.3 s (27.3×) | 132.8 s (75.0×) | — |
| `numeric-abs` | Numeric functions | **1,675.2 ms (1.0×)** | 2,724.9 ms (1.6×) | 12.7 s (7.6×) | 4,236.6 ms (2.5×) | 127.2 s (76.0×) |
| `numeric-add` | Numeric functions | **1,644.8 ms (1.0×)** | 3,734.7 ms (2.3×) | 4,308.4 ms (2.6×) | 4,577.9 ms (2.8×) | 151.4 s (92.0×) |
| `numeric-baseline` | Numeric functions | 1,610.3 ms (1.3×) | **1,201.7 ms (1.0×)** | 9,147.3 ms (7.6×) | 3,614.9 ms (3.0×) | 122.6 s (102.0×) |
| `numeric-ceil` | Numeric functions | **1,675.4 ms (1.0×)** | 2,717.3 ms (1.6×) | 5,642.3 ms (3.4×) | 4,167.3 ms (2.5×) | 123.9 s (73.9×) |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **1.67 ms** | 426.0 ms | 2,807.3 ms | 4,225.9 ms | — |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | **1.49 ms** | 278.0 ms | 1,592.6 ms | 3,883.4 ms | — |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | **1.71 ms** | 361.7 ms | 2,111.9 ms | 4,059.8 ms | — |
| `numeric-floor` | Numeric functions | **1,676.0 ms (1.0×)** | 2,722.8 ms (1.6×) | 5,577.2 ms (3.3×) | 4,202.9 ms (2.5×) | 124.1 s (74.1×) |
| `numeric-greater` | Numeric functions | **0.99 ms** | 1,733.9 ms | 2,832.9 ms | 3,133.3 ms | 125.8 s |
| `numeric-round` | Numeric functions | **1,675.8 ms (1.0×)** | 2,717.5 ms (1.6×) | 5,618.9 ms (3.4×) | 4,274.5 ms (2.6×) | 125.1 s (74.7×) |
| `date-day` | Date functions | 3,723.8 ms (1.7×) | 3,726.9 ms (1.8×) | **2,129.2 ms (1.0×)** | 10.3 s (4.8×) | 117.2 s (55.1×) |
| `date-month` | Date functions | 3,784.0 ms (1.1×) | 3,725.7 ms (1.1×) | **3,502.0 ms (1.0×)** | 10.3 s (2.9×) | 118.3 s (33.8×) |
| `date-year` | Date functions | 3,818.6 ms (1.9×) | 2,796.2 ms (1.4×) | **2,000.2 ms (1.0×)** | 10.4 s (5.2×) | 122.2 s (61.1×) |
| `regex-3` | String / REGEX | **34.6 s (1.0×)** | — | — | — | — |
| `regex-3-contains` | String / REGEX | **8,446.6 ms (1.0×)** | — | 193.7 s (22.9×) | 249.2 s (29.5×) | — |
| `regex-3-fixed` | String / REGEX | **29.8 s (1.0×)** | — | 222.3 s (7.5×) | — | — |
| `regex-prefix-1` | String / REGEX | 1,700.3 ms (7.5×) | **226.9 ms (1.0×)** | 225.3 s (993.1×) | — | — |
| `regex-prefix-2` | String / REGEX | 330.3 ms (6.8×) | **48.6 ms (1.0×)** | 219.2 s (4507.9×) | — | — |
| `regex-prefix-3` | String / REGEX | 141.6 ms (9.9×) | **14.3 ms (1.0×)** | 240.4 s (16786.5×) | — | — |
| `strafter` | String / REGEX | **9,154.8 ms (1.0×)** | — | 254.8 s (27.8×) | — | — |
| `strbefore` | String / REGEX | **9,063.0 ms (1.0×)** | — | 251.5 s (27.8×) | — | — |
| `strends` | String / REGEX | **8,059.6 ms (1.0×)** | — | 205.6 s (25.5×) | 247.2 s (30.7×) | — |
| `strlen` | String / REGEX | **7,977.9 ms (1.0×)** | — | 204.5 s (25.6×) | — | — |
| `strstarts` | String / REGEX | **443.3 ms (1.0×)** | — | 204.2 s (460.7×) | 243.9 s (550.3×) | — |
| `transitive-path-large-join-and-plus` | Transitive paths | **753.5 ms (1.0×)** | — | — | — | — |
| `transitive-path-plus` | Transitive paths | 4,868.1 ms (1.4×) | **3,382.1 ms (1.0×)** | — | 12.1 s (3.6×) | 64.3 s (19.0×) |
| `transitive-path-plus-fixed-subject` | Transitive paths | **1.95 ms** | 5.77 ms | — | 19.0 ms | 26.0 ms |
| `transitive-path-small-join-and-plus` | Transitive paths | **6.07 ms** | 49.9 ms | — | 156.4 ms | 770.0 ms |
| `result-size-large` | Result size / export | **457.1 ms (1.0×)** | 4,104.9 ms (9.0×) | 20.4 s (44.7×) | 1,393.5 ms (3.0×) | 11.6 s (25.4×) |
| `result-size-medium` | Result size / export | **96.2 ms (1.0×)** | 511.9 ms (5.3×) | 640.2 ms (6.7×) | 150.7 ms (1.6×) | 136.0 ms (1.4×) |
| `result-size-small` | Result size / export | 8.28 ms | 34.6 ms | 4.58 ms | **2.25 ms** | 5.00 ms |
| `result-size-tiny` | Result size / export | 6.24 ms | 25.5 ms | 0.72 ms | **0.55 ms** | 3.00 ms |
| `result-size-xlarge` | Result size / export | **4,360.2 ms (1.0×)** | 39.3 s (9.0×) | 21.6 s (4.9×) | 15.6 s (3.6×) | 125.4 s (28.7×) |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 4,964 s (1:22:44) | 1.65 M input triples/s | 252.6 GB peak RSS (includes memory the allocator had freed but not yet returned; available system memory stayed above 381 GB of 505 GB during the import) | 211 GB | From the 2026-11-12 import of this store; the 2026-11-19 query run reused that ledger and did not re-import. Imported from the pinned dump (SHA-256 verified), re-split into 2,047 single-member gzip shards of 4,000,000 lines each: 8,186,371,175 input lines in 4,964 s (1.65 M/s), 2,047 commits, 211,031,698,039-byte ledger. Fluree stores distinct triples: 5,769,091 duplicate statements collapsed, and COUNT(*) after import = 8,180,602,084. |
| QLever | 8,653 s (2:24:13) | 0.95 M triples/s | n/a (mmap index) | 180 GB | Parallel-parsed the single N-Triples stream (no @prefix) at ~2.8M/s from pigz -dc. QLever indexed 8,180,599,054 triples (Fluree: 8,180,602,084 distinct triples, 3,030 more). First attempt failed merging 816 partial vocabularies on the default 1024 fd limit inside Docker; fixed with --ulimit nofile=1048576 and re-ran. |
| Virtuoso | ~108 min (40 min initial + 68 min geo-fix reload) | n/a | n/a | 367 GB (virtuoso.db; 434 GB db dir) | Loaded 8,174,845,462 triples. 629/1444 shards initially aborted on Wikidata geo:wktLiteral (RDFGE error; no INI flag to disable; known Virtuoso issue), fixed by filtering wktLiteral from the failed shards and reloading -> drops ~11.5M geo-coordinate triples (99.86% of dataset). 4 shards hit an RDF_LANGUAGE primary-key race on parallel load. |
| MillenniumDB | 5.05 h (18,193 s) | 0.45 M triples/s | n/a | 327 GB | Imported 8,180,602,084 triples (the same distinct-triple count as Fluree -- cleanest full load of the non-Fluree/QLever engines, no data loss). Server buffer total must stay below available RAM (288GB total failed to allocate right after the import). |
| Apache Jena (TDB2/Fuseki) | ~32 h (xloader) | n/a | n/a | 655 GB | Loaded the full 8,186,371,175 input triples. By far the slowest loader: xloader phases nodes -> ingest data -> build SPO/POS/OSP permutations (each a sort over 8.19B), ~32h total. Largest index of all engines (655 GB). |

- **QLever phases:** parse ~48min, then convert-to-global-ids + 6-permutation sort/build

- **Apache Jena (TDB2/Fuseki) phases:** node table -> data ingest -> 3 permutation index builds (SPO/POS/OSP)

## 4. Environment & dataset

- **Dataset:** Wikidata Truthy — Wikidata 'truthy' dump (latest-truthy.nt.gz): 8,186,371,175 N-Triples lines, 8,180,602,084 distinct triples
  - source: https://dumps.wikimedia.org/wikidatawiki/entities/latest-truthy.nt.gz
  - version: snapshot 2026-05-29 11:17:24 GMT (rolling latest; pinned as GitHub release wikidata-truthy-source-20260529). Paper used 'as of 2025-04-18', no longer on the live mirror. · SHA-256 `9fb5a16502ac05d9b9aad9f161bfe4e3e9ac514e142d7cf5ae4efd030b9f739a`
  - **8,180,602,084 triples**, 13,306 predicates, 250,814,143 subjects, 1,671,906,898 objects · on-disk 70,497,233,745 bytes (~70.5 GB compressed .nt.gz; ~700 GB+ uncompressed)
- **Hardware:** AWS r7a.16xlarge — AMD EPYC (Zen 4), no-SMT, 64 cores, 512 GB RAM, 3 TB gp3 (12000 IOPS / 600 MB/s), Ubuntu 24.04
- **Method:** 1 warmup + 3 timed runs, median reported, 300 s timeout, results as `text/tab-separated-values`
  - QLever result cache disabled + cleared per query. Reference engine: QLever.

| engine | version | config |
|---|---|---|
| Fluree | v4.2.8 | x86_64 Linux build (`fluree --version` = `fluree 4.2.8`). Server: `fluree server run --listen-addr 127.0.0.1:8090`, default cache. Queries measured 2026-11-19 on the retained ledger from the 2026-11-12 import of the same store (no re-import; COUNT(*) re-checked = 8,180,602,084). That import: `fluree create wikidata --from <shards dir>` with default (automatic) settings -- memory budget 403,980 MB, parallelism 64, chunk size 768 MB; ulimit -n 1048576. |
| QLever | latest (`b802870 (adfreiburg/qlever:latest)`) | index -m 300G, num-triples-per-batch 10M, vocab on-disk-compressed; server MEMORY_FOR_QUERIES 200G, result cache disabled+cleared per query; docker --ulimit nofile=1048576 (required for vocab merge) |
| Virtuoso | 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7) (`07.20.3229`) | NumberOfBuffers 32M / MaxDirtyBuffers 24M (~256GB), ServerThreads 200, MaxQueryExecutionTime 300s, ResultSetMaxRows 10M. Loaded via ld_dir of 1444 single-member .nt.gz shards into graph <https://www.wikidata.org/>, 32 parallel rdf_loader_run. Queries: form-POST (url-encoded query=) + default-graph-uri. No result cache (warm buffers, like Fluree). |
| MillenniumDB | v1.0.0 (`6118e08 (built from source)`) | cmake Release build (deps: libboost-all-dev, libicu-dev, libncurses-dev, libssl-dev). Import: pigz -dc | mdb import --format ttl --buffer-strings 100GB --buffer-tensors 100GB. Server: --versioned-buffer 120GB, strings 15/10GB, tensors 5/5GB, --threads 64 --timeout 300. Endpoint :1234/sparql (body POST). No result cache. |
| Apache Jena (TDB2/Fuseki) | 6.1.0 | TDB2 store built with tdb2.xloader (--loc ~/tdb2-wikidata). Served via Fuseki (JVM -Xmx64g, --timeout=300000 i.e. 300s, dataset /wikidata). Endpoint :3030/wikidata/sparql (body POST). No result cache. openjdk-21 (Temurin not needed). |

**Caveats**
- Wikidata Truthy is the second dataset with a published SPARQLoscope reference (alongside DBLP).
- NOT comparable to the published SPARQLoscope table / paper: that used the 2025-04-18 truthy snapshot (~7.94B, gone from the live mirror); this is the 2026-05-29 snapshot (~8.19B input lines). Engine-vs-engine on this hardware specification is valid; absolute per-query COUNTs will not match the paper's reference yaml.
- Fluree v4.2.8, measured 2026-11-19 with default settings on the ledger imported 2026-11-12: 105/105 completed, no timeouts. With zero failures the P=2/P=10 penalized means equal the plain means. Many SPARQLoscope queries are COUNT-dominated, which suits Fluree — weigh the aggregate lead accordingly. Fluree is not fastest everywhere: QLever leads the String / REGEX prefix queries, filter-language-en and several dataset-statistics counts (number-of-objects: Fluree 538 ms vs QLever 1.2 ms), and Virtuoso, MillenniumDB or Jena lead a number of small-result joins (see §1b–§1c).
- Timings are recorded as fractional milliseconds from curl's %{time_total}. For QLever, Virtuoso and MillenniumDB every successful response body was saved (--save-outputs) and archived under s3://fluree-benchmark-data/runs/wikidata-truthy-20260610/<engine>/query-outputs/ as a debugging record. Jena's numbers carry whole-second rounding (benchmarked 2026-06-05; the ~32 h reload made re-benchmarking on the fractional-ms harness impractical).
- The engines were not measured at the same time: Fluree v4.2.8 ran on 2026-11-19, the other engines in June 2026, each on its own r7a.16xlarge with the same disk configuration, the same pinned dump and the same harness and query files. Full-sweep timings at this scale are also cache-state sensitive (the same query can measure tens of percent differently depending on what ran before it), so treat per-query differences under ~20% as within environmental noise.
- QLever result cache disabled + cleared per query (re-executes each run) to match Fluree's no-result-cache behavior; stricter than the paper's run-once-with-warm-cache protocol.
- Counting answers: Fluree stores distinct triples — COUNT(*) = 8,180,602,084 from 8,186,371,175 input lines (5,769,091 duplicate statements collapsed) — the same count MillenniumDB imported. QLever indexed 8,180,599,054 (3,030 fewer). Fluree and QLever agree exactly on 13,306 predicates and 250,814,143 subjects. Literal counts differ by the same 3,030 (Fluree 6,788,371,325 vs QLever 6,788,368,295) and distinct-object counts by 79,568 (Fluree 1,671,906,898 vs QLever 1,671,827,330, 0.005%); the cause of these differences was not investigated.
- Both Fluree and QLever were indexed with a raised open-file limit (nofile 1048576): Fluree's import ran with ulimit -n 1048576, and QLever's vocabulary merge failed on the default 1024 fd limit inside Docker until --ulimit was set.
- Result-equivalence (per-query correctness): no full multi-row result-equivalence diff was run. The counting answers above are the cross-engine check available for this run; all 105 Fluree responses returned HTTP 200.
- Virtuoso (benchmarked 2026-06-11) loaded 8,168,210,937 triples: Wikidata's geo:wktLiteral coordinates trigger Virtuoso's RDFGE error which aborts whole load shards (no INI flag to disable), so this run pre-filters wktLiteral from all shards uniformly (~11.5M geo-coordinate triples dropped, see common/engine-setup/virtuoso.md). To give Virtuoso its best result, the stock ini's MaxQueryCostEstimationTime=400 gate was disabled (=0) -- with it, Virtuoso rejects the big join queries with HTTP 500 'estimated execution time exceeds the limit' before executing (join-2-largest-result and others would not run at all); the 300s execution timeout still applies. 81/105 passed.
- MillenniumDB (benchmarked 2026-06-11) loaded the full 8,180,602,084 triples (matches QLever exactly). 67/105 passed, no HTTP errors -- slowest of the loaded engines on the heavy COUNT/join/string categories, but a clean complete load. COUNT(*) is not verifiable post-load on MDB (a full scan exceeds its own 300s timeout); load verified by import stats + the 327 GB index.
- Apache Jena loaded the full 8,186,371,175 triples but is the weakest at query time: 31/105 passed, 74 timeouts (no HTTP errors). Cold TDB2 page reads on the 655 GB index + no COUNT fastpath mean the COUNT-dominated SPARQLoscope queries overwhelmingly hit the 300s cap (geo-mean P=2 151.5 s; with 74 of 105 queries timing out, the median query hits the 300 s cap).
