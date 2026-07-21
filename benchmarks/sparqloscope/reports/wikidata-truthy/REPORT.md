# SPARQLoscope benchmark — Wikidata Truthy

> **Run 2026-06-10..12 (fractional-ms timings via curl %{time_total}; per-run response bodies saved and archived to S3): Fluree, QLever, Virtuoso, MillenniumDB benchmarked on fresh boxes; Jena benchmarked 2026-06-05 with whole-second timing precision (too slow to reload, ~32h). Fluree v4.0.6: 105/105 PASSED -- the only engine to answer all 105, including the string/regex/groupconcat heavyweights (group-by-implicit-string-min/max ~120ms, group-by-string-groupconcat 1.9s via the SUM(STRLEN(GROUP_CONCAT)) algebraic identity, distinct-count 2ms, regex/str* family 8-33s). Passed: Fluree 105/105, QLever 91/105, Virtuoso 81/105 (cost-estimation gate disabled; loaded 8.168B with wktLiteral pre-filtered), MillenniumDB 67/105 (full load), Apache Jena 31/105 (whole-second timings). Blazegraph EXCLUDED (silently drops blank nodes; at its scale ceiling at 8B). 105 queries, 1 warmup + 3 runs, 300s timeout (early-abort). Run artifacts incl. per-query result bodies: s3://fluree-benchmark-data/runs/wikidata-truthy-20260610/. Engine-vs-engine on this box only; not comparable to the paper's 2025-04-18 snapshot.**

**Dataset:** 8,186,371,175 triples, 13,306 predicates (snapshot 2026-05-29 11:17:24 GMT (rolling latest; pinned as GitHub release wikidata-truthy-source-20260529). Paper used 'as of 2025-04-18', no longer on the live mirror.) · **Engines:** Fluree v4.0.6, QLever latest, Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0, Apache Jena (TDB2/Fuseki) 6.1.0 · **Box:** AWS r7a.16xlarge (64c / 512 GB) · 1+3 runs, median, 300 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Virtuoso | MillenniumDB | Apache Jena (TDB2/Fuseki) |
|---|---|---|---|---|---|
| passed | 105/105 | 91/105 | 81/105 | 67/105 | 31/105 |
| geo mean (P=2) | **367.4 ms (1.0×)** | 3,833.3 ms (10.4×) | 12.9 s (35.1×) | 28.7 s (78.1×) | 151.5 s (412.4×) |
| geo mean (P=10) | **367.4 ms (1.0×)** | 4,750.8 ms (12.9×) | 18.6 s (50.7×) | 51.4 s (139.8×) | 471.0 s (1282.1×) |
| geo mean (passed only) | **367.4 ms (1.0×)** | 1,761.8 ms (4.8×) | 4,134.7 ms (11.3×) | 5,112.1 ms (13.9×) | 5,668.9 ms (15.4×) |
| arith mean (passed only) | **4,911.0 ms (1.0×)** | 18.3 s (3.7×) | 51.1 s (10.4×) | 59.4 s (12.1×) | 75.3 s (15.3×) |
| median (passed only) | **902.6 ms (1.0×)** | 2,796.2 ms (3.1×) | 9,147.3 ms (10.1×) | 10.3 s (11.4×) | 118.3 s (131.1×) |

_geo mean (P=2/P=10) is the SPARQLoscope paper's official aggregate: a failed or timed-out query counts as 2× / 10× the 300 s timeout. The passed-only rows average each engine's completed queries only, so they flatter engines with many failures._

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Virtuoso | MillenniumDB | Apache Jena (TDB2/Fuseki) |
|---|---|---|---|---|
| 1.36× | 7.65× | 16.35× | 26.29× | 61.21× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Virtuoso | MillenniumDB | Apache Jena (TDB2/Fuseki) | fastest |
|---|--:|---|---|---|---|---|---|
| Dataset statistics | 6 | 13.5 ms (1.1×) | **12.7 ms (1.0×)** | 2,177.9 ms (171.7×) | 208.4 s (16427.3×) | — | QLever |
| JOIN | 12 | 392.9 ms (4.1×) | 2,648.2 ms (27.6×) | 773.0 ms (8.1×) | **95.9 ms (1.0×)** | 496.6 ms (5.2×) | MillenniumDB |
| OPTIONAL | 10 | 547.3 ms (16.1×) | 11.0 s (323.4×) | 2,901.8 ms (85.3×) | 11.2 s (330.5×) | **34.0 ms (1.0×)** | Apache Jena (TDB2/Fuseki) |
| MINUS | 10 | **667.8 ms (1.0×)** | 10.1 s (15.2×) | 3,918.7 ms (5.9×) | 12.7 s (19.0×) | — | Fluree |
| EXISTS | 10 | 654.3 ms | 16.6 s | 530.2 ms | 14.6 s | **9.00 ms** | Apache Jena (TDB2/Fuseki) |
| UNION | 5 | **659.2 ms (1.0×)** | 9,543.0 ms (14.5×) | 14.8 s (22.4×) | 106.9 s (162.2×) | — | Fluree |
| GROUP BY / aggregate | 16 | **91.3 ms (1.0×)** | 835.7 ms (9.2×) | 3,912.3 ms (42.8×) | 5,090.8 ms (55.8×) | 43.4 s (475.3×) | Fluree |
| FILTER | 3 | 2,448.4 ms (1.6×) | **1,546.5 ms (1.0×)** | 48.0 s (31.0×) | 107.6 s (69.6×) | — | QLever |
| Numeric functions | 10 | **162.2 ms (1.0×)** | 1,337.1 ms (8.2×) | 4,340.1 ms (26.8×) | 4,017.6 ms (24.8×) | 128.3 s (791.0×) | Fluree |
| Date functions | 3 | 3,797.2 ms (1.5×) | 3,386.2 ms (1.4×) | **2,461.5 ms (1.0×)** | 10.3 s (4.2×) | 119.2 s (48.4×) | Virtuoso |
| String / REGEX | 11 | 4,766.7 ms (88.2×) | **54.1 ms (1.0×)** | 221.3 s (4093.1×) | 246.8 s (4564.9×) | — | QLever |
| Transitive paths | 4 | 113.4 ms (1.1×) | **99.2 ms (1.0×)** | — | 329.9 ms (3.3×) | 1,087.9 ms (11.0×) | QLever |
| Result size / export | 5 | 124.9 ms (1.5×) | 592.0 ms (7.1×) | 247.4 ms (3.0×) | **83.5 ms (1.0×)** | 312.2 ms (3.7×) | MillenniumDB |

### 1c. Per query

| query | category | Fluree | QLever | Virtuoso | MillenniumDB | Apache Jena (TDB2/Fuseki) |
|---|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **1.37 ms** | 17.3 ms | 6.41 ms | 180.0 s | — |
| `number-of-literals` | Dataset statistics | **11.6 s (1.0×)** | 148.4 s (12.8×) | 71.7 s (6.2×) | 250.0 s (21.5×) | — |
| `number-of-objects` | Dataset statistics | 20.8 ms | **1.16 ms** | — | — | — |
| `number-of-predicates` | Dataset statistics | **0.80 ms** | 1.07 ms | — | — | — |
| `number-of-subjects` | Dataset statistics | 20.6 ms | **1.12 ms** | — | — | — |
| `number-of-triples` | Dataset statistics | **1.13 ms** | 1.16 ms | 22.5 s | 201.1 s | — |
| `join-2-large-large` | JOIN | **902.6 ms (1.0×)** | 23.8 s (26.4×) | 156.5 s (173.3×) | — | — |
| `join-2-large-large-with-large-result` | JOIN | **712.2 ms (1.0×)** | 12.6 s (17.8×) | 138.4 s (194.3×) | 163.0 s (228.8×) | — |
| `join-2-large-large-with-small-result` | JOIN | **83.8 ms (1.0×)** | 560.3 ms (6.7×) | 527.9 ms (6.3×) | 7,664.5 ms (91.5×) | 149.7 s (1786.8×) |
| `join-2-large-small` | JOIN | 31.8 ms | 55.3 ms | **4.36 ms** | 8.70 ms | — |
| `join-2-largest-result` | JOIN | **1,202.2 ms (1.0×)** | 16.6 s (13.8×) | 243.7 s (202.7×) | — | — |
| `join-2-small-large` | JOIN | 32.4 ms | 53.0 ms | **4.24 ms** | 16.8 ms | 30.0 ms |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | 28.9 s (1.6×) | **18.4 s (1.0×)** | — | — | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **2,661.3 ms (1.0×)** | 23.1 s (8.7×) | 22.8 s (8.5×) | — | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | 1.42 ms | 841.4 ms | **0.76 ms** | 1.61 ms | 7.00 ms |
| `join-xlarge-star-on-small-predicates` | JOIN | 23.5 ms | 90.3 ms | **0.75 ms** | 1.40 ms | 10.0 ms |
| `multicolumn-join-large` | JOIN | **21.9 s (1.0×)** | 116.0 s (5.3×) | 52.5 s (2.4×) | — | — |
| `multicolumn-join-small` | JOIN | 3,610.9 ms (19.8×) | 3,865.1 ms (21.2×) | 1,677.3 ms (9.2×) | **182.4 ms (1.0×)** | 96.1 s (526.9×) |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **759.9 ms (1.0×)** | 64.8 s (85.3×) | — | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | **172.9 ms (1.0×)** | 1,674.1 ms (9.7×) | 615.5 ms (3.6×) | 76.1 s (440.3×) | — |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | **87.2 ms (1.0×)** | 1,654.4 ms (19.0×) | 861.9 ms (9.9×) | 75.4 s (865.5×) | — |
| `optional-join-3-chain-1` | OPTIONAL | 31.8 s (1.6×) | **19.4 s (1.0×)** | — | — | — |
| `optional-join-3-chain-2` | OPTIONAL | **27.0 s (1.0×)** | — | — | — | — |
| `optional-join-3-star-1` | OPTIONAL | **2,669.8 ms (1.0×)** | 111.6 s (41.8×) | 49.6 s (18.6×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **2,177.9 ms (1.0×)** | 78.6 s (36.1×) | 70.4 s (32.3×) | 200.0 s (91.8×) | — |
| `optional-join-large-large` | OPTIONAL | **921.1 ms (1.0×)** | 79.5 s (86.3×) | — | — | — |
| `optional-join-large-small` | OPTIONAL | **1.42 ms** | 18.7 s | 64.1 s | — | — |
| `optional-join-small-large` | OPTIONAL | 32.3 ms | 51.7 ms | **5.03 ms** | 13.9 ms | 34.0 ms |
| `minus-join-2-large-large-with-large-result` | MINUS | **681.2 ms (1.0×)** | 28.0 s (41.0×) | — | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | **56.8 ms (1.0×)** | 614.4 ms (10.8×) | 587.2 ms (10.3×) | 75.8 s (1334.5×) | — |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **57.0 ms (1.0×)** | 728.3 ms (12.8×) | 823.7 ms (14.5×) | 75.0 s (1316.4×) | — |
| `minus-join-3-chain-1` | MINUS | 19.8 s (1.3×) | **15.2 s (1.0×)** | 116.1 s (7.7×) | 108.1 s (7.1×) | — |
| `minus-join-3-chain-2` | MINUS | **24.6 s (1.0×)** | — | — | — | — |
| `minus-join-3-star-1` | MINUS | **13.1 s (1.0×)** | 85.6 s (6.5×) | 29.4 s (2.2×) | — | — |
| `minus-join-3-star-2` | MINUS | **1,483.2 ms (1.0×)** | 57.3 s (38.7×) | 23.7 s (16.0×) | 119.2 s (80.4×) | — |
| `minus-join-large-large` | MINUS | **870.8 ms (1.0×)** | 27.4 s (31.4×) | — | — | — |
| `minus-join-large-small` | MINUS | **31.2 ms (1.0×)** | 27.6 s (886.4×) | 63.2 s (2029.1×) | — | — |
| `minus-join-small-large` | MINUS | 31.1 ms | 1,595.6 ms | 5.75 ms | **4.49 ms** | — |
| `exists-join-2-large-large-with-large-result` | EXISTS | **673.8 ms (1.0×)** | 48.5 s (72.0×) | — | — | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | **56.0 ms (1.0×)** | 1,101.3 ms (19.7×) | 593.1 ms (10.6×) | 75.1 s (1339.7×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **59.2 ms (1.0×)** | 957.0 ms (16.2×) | 798.8 ms (13.5×) | 72.2 s (1218.5×) | — |
| `exists-join-3-chain-1` | EXISTS | **20.0 s (1.0×)** | 26.7 s (1.3×) | 116.3 s (5.8×) | 113.9 s (5.7×) | — |
| `exists-join-3-chain-2` | EXISTS | **23.4 s (1.0×)** | — | — | — | — |
| `exists-join-3-star-1` | EXISTS | **13.0 s (1.0×)** | 26.2 s (2.0×) | — | — | — |
| `exists-join-3-star-2` | EXISTS | **1,466.8 ms (1.0×)** | 94.6 s (64.5×) | 20.8 s (14.2×) | 130.5 s (88.9×) | — |
| `exists-join-large-large` | EXISTS | **847.3 ms (1.0×)** | 66.2 s (78.1×) | — | — | — |
| `exists-join-large-small` | EXISTS | 29.2 ms | 26.7 s | **4.53 ms** | — | — |
| `exists-join-small-large` | EXISTS | 29.2 ms | 16.3 s | **4.29 ms** | 8.16 ms | 9.00 ms |
| `union-constraint-filter-restrictive` | UNION | 33.9 s (8.3×) | 33.4 s (8.2×) | **4,074.9 ms (1.0×)** | 105.7 s (25.9×) | — |
| `union-constraint-from-star` | UNION | **2,467.4 ms (1.0×)** | 19.9 s (8.1×) | 31.3 s (12.7×) | 196.6 s (79.7×) | — |
| `union-constraint-large-join` | UNION | **975.1 ms (1.0×)** | 16.1 s (16.5×) | 146.9 s (150.7×) | 208.8 s (214.1×) | — |
| `union-constraint-small-join` | UNION | **1,231.2 ms (1.0×)** | 3,053.2 ms (2.5×) | 1,822.7 ms (1.5×) | 29.2 s (23.7×) | — |
| `union-no-constraint` | UNION | **1.24 ms** | 2,436.7 ms | 20.4 s | 110.2 s | — |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **0.90 ms** | 26.5 ms | 97.0 ms | 86.4 ms | 216.0 ms |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **2.19 ms** | — | — | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 20.0 s (2.6×) | **7,595.2 ms (1.0×)** | 10.1 s (1.3×) | 12.8 s (1.7×) | — |
| `group-by-complex-aggregate` | GROUP BY / aggregate | 17.1 s (1.5×) | **11.5 s (1.0×)** | 88.9 s (7.7×) | — | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | **1.51 ms** | 2.56 ms | 17.9 ms | 33.5 ms | — |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **3,951.6 ms (1.0×)** | 52.6 s (13.3×) | — | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | 17.0 s (19.3×) | 9,744.1 ms (11.1×) | **878.7 ms (1.0×)** | 13.3 s (15.2×) | — |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | 1,929.6 ms (1.6×) | **1,203.9 ms (1.0×)** | 13.4 s (11.2×) | 3,673.5 ms (3.1×) | 126.6 s (105.2×) |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | **0.85 ms** | 2.46 ms | 891.8 ms | 3,294.2 ms | 121.9 s |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **1.96 ms** | 1,106.9 ms | 4,519.0 ms | 3,740.4 ms | 127.4 s |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **2.14 ms** | 1,134.2 ms | 2,892.7 ms | 3,810.4 ms | 125.9 s |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | 1,696.0 ms (1.4×) | **1,200.8 ms (1.0×)** | 9,095.2 ms (7.6×) | 3,638.9 ms (3.0×) | 124.8 s (103.9×) |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | **1.06 ms** | 6.73 ms | 9,811.8 ms | 89.2 s | — |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **120.2 ms (1.0×)** | 29.5 s (245.2×) | 62.1 s (517.0×) | 103.5 s (861.0×) | — |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **121.2 ms (1.0×)** | 30.1 s (247.9×) | 42.5 s (350.6×) | 105.6 s (871.3×) | — |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **1,913.8 ms (1.0×)** | — | — | — | — |
| `filter-few-results` | FILTER | **1,824.7 ms (1.0×)** | 27.5 s (15.1×) | 47.7 s (26.1×) | 87.1 s (47.7×) | — |
| `filter-language-en` | FILTER | 4,194.8 ms | **2.71 ms** | — | — | — |
| `filter-many-results` | FILTER | **1,917.6 ms (1.0×)** | 49.6 s (25.9×) | 48.3 s (25.2×) | 132.8 s (69.3×) | — |
| `numeric-abs` | Numeric functions | **1,727.5 ms (1.0×)** | 2,724.9 ms (1.6×) | 12.7 s (7.4×) | 4,236.6 ms (2.5×) | 127.2 s (73.7×) |
| `numeric-add` | Numeric functions | **1,747.2 ms (1.0×)** | 3,734.7 ms (2.1×) | 4,308.4 ms (2.5×) | 4,577.9 ms (2.6×) | 151.4 s (86.7×) |
| `numeric-baseline` | Numeric functions | 1,712.0 ms (1.4×) | **1,201.7 ms (1.0×)** | 9,147.3 ms (7.6×) | 3,614.9 ms (3.0×) | 122.6 s (102.0×) |
| `numeric-ceil` | Numeric functions | **1,729.6 ms (1.0×)** | 2,717.3 ms (1.6×) | 5,642.3 ms (3.3×) | 4,167.3 ms (2.4×) | 123.9 s (71.6×) |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **7.67 ms** | 426.0 ms | 2,807.3 ms | 4,225.9 ms | — |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | **7.29 ms** | 278.0 ms | 1,592.6 ms | 3,883.4 ms | — |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | **6.47 ms** | 361.7 ms | 2,111.9 ms | 4,059.8 ms | — |
| `numeric-floor` | Numeric functions | **1,729.4 ms (1.0×)** | 2,722.8 ms (1.6×) | 5,577.2 ms (3.2×) | 4,202.9 ms (2.4×) | 124.1 s (71.8×) |
| `numeric-greater` | Numeric functions | **1.31 ms** | 1,733.9 ms | 2,832.9 ms | 3,133.3 ms | 125.8 s |
| `numeric-round` | Numeric functions | **1,722.3 ms (1.0×)** | 2,717.5 ms (1.6×) | 5,618.9 ms (3.3×) | 4,274.5 ms (2.5×) | 125.1 s (72.7×) |
| `date-day` | Date functions | 3,806.5 ms (1.8×) | 3,726.9 ms (1.8×) | **2,129.2 ms (1.0×)** | 10.3 s (4.8×) | 117.2 s (55.1×) |
| `date-month` | Date functions | 3,772.8 ms (1.1×) | 3,725.7 ms (1.1×) | **3,502.0 ms (1.0×)** | 10.3 s (2.9×) | 118.3 s (33.8×) |
| `date-year` | Date functions | 3,812.4 ms (1.9×) | 2,796.2 ms (1.4×) | **2,000.2 ms (1.0×)** | 10.4 s (5.2×) | 122.2 s (61.1×) |
| `regex-3` | String / REGEX | **33.0 s (1.0×)** | — | — | — | — |
| `regex-3-contains` | String / REGEX | **8,807.2 ms (1.0×)** | — | 193.7 s (22.0×) | 249.2 s (28.3×) | — |
| `regex-3-fixed` | String / REGEX | **26.4 s (1.0×)** | — | 222.3 s (8.4×) | — | — |
| `regex-prefix-1` | String / REGEX | 4,413.9 ms (19.5×) | **226.9 ms (1.0×)** | 225.3 s (993.1×) | — | — |
| `regex-prefix-2` | String / REGEX | 656.4 ms (13.5×) | **48.6 ms (1.0×)** | 219.2 s (4507.9×) | — | — |
| `regex-prefix-3` | String / REGEX | 276.7 ms (19.3×) | **14.3 ms (1.0×)** | 240.4 s (16786.5×) | — | — |
| `strafter` | String / REGEX | **9,215.5 ms (1.0×)** | — | 254.8 s (27.6×) | — | — |
| `strbefore` | String / REGEX | **9,150.5 ms (1.0×)** | — | 251.5 s (27.5×) | — | — |
| `strends` | String / REGEX | **8,501.5 ms (1.0×)** | — | 205.6 s (24.2×) | 247.2 s (29.1×) | — |
| `strlen` | String / REGEX | **8,435.3 ms (1.0×)** | — | 204.5 s (24.2×) | — | — |
| `strstarts` | String / REGEX | **777.2 ms (1.0×)** | — | 204.2 s (262.7×) | 243.9 s (313.9×) | — |
| `transitive-path-large-join-and-plus` | Transitive paths | **898.7 ms (1.0×)** | — | — | — | — |
| `transitive-path-plus` | Transitive paths | 8,187.5 ms (2.4×) | **3,382.1 ms (1.0×)** | — | 12.1 s (3.6×) | 64.3 s (19.0×) |
| `transitive-path-plus-fixed-subject` | Transitive paths | **2.47 ms** | 5.77 ms | — | 19.0 ms | 26.0 ms |
| `transitive-path-small-join-and-plus` | Transitive paths | **9.11 ms** | 49.9 ms | — | 156.4 ms | 770.0 ms |
| `result-size-large` | Result size / export | **670.4 ms (1.0×)** | 4,104.9 ms (6.1×) | 20.4 s (30.4×) | 1,393.5 ms (2.1×) | 11.6 s (17.3×) |
| `result-size-medium` | Result size / export | **104.0 ms (1.0×)** | 511.9 ms (4.9×) | 640.2 ms (6.2×) | 150.7 ms (1.4×) | 136.0 ms (1.3×) |
| `result-size-small` | Result size / export | 8.74 ms | 34.6 ms | 4.58 ms | **2.25 ms** | 5.00 ms |
| `result-size-tiny` | Result size / export | 7.73 ms | 25.5 ms | 0.72 ms | **0.55 ms** | 3.00 ms |
| `result-size-xlarge` | Result size / export | **6,451.6 ms (1.0×)** | 39.3 s (6.1×) | 21.6 s (3.3×) | 15.6 s (2.4×) | 125.4 s (19.4×) |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 5,227 s (1:27:07) | 1.57 M flakes/s | ~104 GB | 201 GB | Ledger imported 2026-06-10: 8,186,371,175 flakes across 2047 commits @ 1.57 M flakes/s, 201 GB index. Imported from a directory of 2047 single-member gzip shards (~4M triples each, re-split from the 70 GB multi-member gzip): Fluree's streaming chunker requires single-member shards for this high-prefix-cardinality data. Sanity COUNT(*) = 8,186,371,175 (exact match). |
| QLever | 8,653 s (2:24:13) | 0.95 M triples/s | n/a (mmap index) | 180 GB | Parallel-parsed the single N-Triples stream (no @prefix) at ~2.8M/s from pigz -dc. QLever indexed 8,180,599,054 triples (Fluree 8,186,371,175; +0.07% delta — QLever dedups exact-duplicate triples). First attempt failed merging 816 partial vocabularies on the default 1024 fd limit inside Docker; fixed with --ulimit nofile=1048576 and re-ran. |
| Virtuoso | ~108 min (40 min initial + 68 min geo-fix reload) | n/a | n/a | 367 GB (virtuoso.db; 434 GB db dir) | Loaded 8,174,845,462 triples. 629/1444 shards initially aborted on Wikidata geo:wktLiteral (RDFGE error; no INI flag to disable; known Virtuoso issue), fixed by filtering wktLiteral from the failed shards and reloading -> drops ~11.5M geo-coordinate triples (99.86% of dataset). 4 shards hit an RDF_LANGUAGE primary-key race on parallel load. |
| MillenniumDB | 5.05 h (18,193 s) | 0.45 M triples/s | n/a | 327 GB | Imported 8,180,602,084 triples (matches QLever's 8.18B exactly -- cleanest full load of the non-Fluree/QLever engines, no data loss). Server buffer total must stay below available RAM (288GB total failed to allocate right after the import). |
| Apache Jena (TDB2/Fuseki) | ~32 h (xloader) | n/a | n/a | 655 GB | Loaded the full 8,186,371,175 triples (matches Fluree exactly). By far the slowest loader: xloader phases nodes -> ingest data -> build SPO/POS/OSP permutations (each a sort over 8.19B), ~32h total. Largest index of all engines (655 GB). |

- **Fluree phases:** parse+commit to storage, then single-threaded index sort/merge buffering (peak ~104 GB RAM), then flush to 201 GB index

- **QLever phases:** parse ~48min, then convert-to-global-ids + 6-permutation sort/build

- **Apache Jena (TDB2/Fuseki) phases:** node table -> data ingest -> 3 permutation index builds (SPO/POS/OSP)

## 4. Environment & dataset

- **Dataset:** Wikidata Truthy — Wikidata 'truthy' dump (latest-truthy.nt.gz)
  - source: https://dumps.wikimedia.org/wikidatawiki/entities/latest-truthy.nt.gz
  - version: snapshot 2026-05-29 11:17:24 GMT (rolling latest; pinned as GitHub release wikidata-truthy-source-20260529). Paper used 'as of 2025-04-18', no longer on the live mirror. · SHA-256 `9fb5a16502ac05d9b9aad9f161bfe4e3e9ac514e142d7cf5ae4efd030b9f739a`
  - **8,186,371,175 triples**, 13,306 predicates, 250,814,143 subjects, 1,660,872,132 objects · on-disk 70,497,233,745 bytes (~70.5 GB compressed .nt.gz; ~700 GB+ uncompressed)
- **Hardware:** AWS r7a.16xlarge — AMD EPYC (Zen 4), no-SMT, 64 cores, 512 GB RAM, 3 TB gp3 (12000 IOPS / 600 MB/s), Ubuntu 24.04
- **Method:** 1 warmup + 3 timed runs, median reported, 300 s timeout, results as `text/tab-separated-values`
  - QLever result cache disabled + cleared per query. Reference engine: QLever.

| engine | version | config |
|---|---|---|
| Fluree | v4.0.6 | server cache auto (~252 GB / 50% RAM); inline-indexed ledger; ulimit -n raised to 1048576 for the import. Built from source: cargo build --release -p fluree-db-cli; benchmarked natively 2026-06-12. v4.0.6 includes per-distinct-string folds for regex/contains/strlen aggregates, COUNT(DISTINCT) from POST lead groups, materialized encoded bindings for value-folding aggregates, and SUM(STRLEN(GROUP_CONCAT)) via algebraic identity. |
| QLever | latest (`b802870 (adfreiburg/qlever:latest)`) | index -m 300G, num-triples-per-batch 10M, vocab on-disk-compressed; server MEMORY_FOR_QUERIES 200G, result cache disabled+cleared per query; docker --ulimit nofile=1048576 (required for vocab merge) |
| Virtuoso | 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7) (`07.20.3229`) | NumberOfBuffers 32M / MaxDirtyBuffers 24M (~256GB), ServerThreads 200, MaxQueryExecutionTime 300s, ResultSetMaxRows 10M. Loaded via ld_dir of 1444 single-member .nt.gz shards into graph <https://www.wikidata.org/>, 32 parallel rdf_loader_run. Queries: form-POST (url-encoded query=) + default-graph-uri. No result cache (warm buffers, like Fluree). |
| MillenniumDB | v1.0.0 (`6118e08 (built from source)`) | cmake Release build (deps: libboost-all-dev, libicu-dev, libncurses-dev, libssl-dev). Import: pigz -dc | mdb import --format ttl --buffer-strings 100GB --buffer-tensors 100GB. Server: --versioned-buffer 120GB, strings 15/10GB, tensors 5/5GB, --threads 64 --timeout 300. Endpoint :1234/sparql (body POST). No result cache. |
| Apache Jena (TDB2/Fuseki) | 6.1.0 | TDB2 store built with tdb2.xloader (--loc ~/tdb2-wikidata). Served via Fuseki (JVM -Xmx64g, --timeout=300000 i.e. 300s, dataset /wikidata). Endpoint :3030/wikidata/sparql (body POST). No result cache. openjdk-21 (Temurin not needed). |

**Caveats**
- Wikidata Truthy is the second dataset with a published SPARQLoscope reference (alongside DBLP).
- NOT comparable to the published SPARQLoscope table / paper: that used the 2025-04-18 truthy snapshot (~7.94B, gone from the live mirror); this is the current 2026-05-29 snapshot (~8.19B). Engine-vs-engine on this box is valid; absolute per-query COUNTs will not match the paper's reference yaml.
- Fluree is v4.0.6, benchmarked 2026-06-12: 105/105 passed. Per-distinct-string folds, COUNT(DISTINCT)-from-POST-lead-groups, and the SUM(STRLEN(GROUP_CONCAT)) algebraic identity let the string/regex/groupconcat heavyweights complete (group-by-implicit-string-min/max ~120 ms, group-by-string-groupconcat 1.9 s, distinct-count-object-low-multiplicity 2 ms, regex family 8.7-33 s, str* family 7.9-9.0 s). With zero failures the P=2/P=10 penalized means equal the plain means. Fluree is COUNT-optimized and the SPARQLoscope queries are COUNT-dominated — weigh the aggregate lead accordingly.
- Timings are recorded as fractional milliseconds from curl's %{time_total}, and every successful response body is saved (--save-outputs) and archived under s3://fluree-benchmark-data/runs/wikidata-truthy-20260610/<engine>/query-outputs/ as a debugging record. Jena's numbers carry whole-second rounding (benchmarked 2026-06-05; the ~32 h reload made re-benchmarking on the fractional-ms harness impractical).
- Full-bench timings at this scale are cache-state sensitive: several queries (union-constraint family, filter-language-en, transitive paths, join-3-chain) measure 15-80% differently between full-bench context and isolated execution, and between full-bench runs, with no binary change — established by interleaved same-box A/B testing. Treat per-query deltas under ~20% between runs as within environmental noise unless reproduced isolated.
- QLever result cache disabled + cleared per query (re-executes each run) to match Fluree's no-result-cache behavior; stricter than the paper's run-once-with-warm-cache protocol.
- Triple-count delta: Fluree 8,186,371,175 vs QLever 8,180,599,054 (+0.07%) — different exact-duplicate handling on import (QLever dedups exact-duplicate triples). Both agree exactly on 13,306 predicates and 250,814,143 subjects; distinct-object counts differ (Fluree 1,660,872,132 vs QLever 1,671,827,330, ~0.66%) — literal-normalization difference.
- Both engines required a raised open-file limit (nofile 1048576) to index 8B triples: Fluree's import and QLever's vocabulary merge each hit the default 1024 fd limit (Fluree natively; QLever inside Docker via --ulimit).
- Result-equivalence (per-query correctness): a 60s spot-check shows count queries mostly agree exactly between engines (e.g. exists-join-2-large-large-with-large-result = 1,702,521,603 both); join-family queries (exists/minus/optional with small results) diverge ~0.2-0.7%, tracking the triple-count delta plus OPTIONAL/blank-node semantics. (Full multi-row result-equivalence diffing is out of scope for this run.)
- Virtuoso (benchmarked 2026-06-11) loaded 8,168,210,937 triples: Wikidata's geo:wktLiteral coordinates trigger Virtuoso's RDFGE error which aborts whole load shards (no INI flag to disable), so this run pre-filters wktLiteral from all shards uniformly (~11.5M geo-coordinate triples dropped, see common/engine-setup/virtuoso.md). To give Virtuoso its best result, the stock ini's MaxQueryCostEstimationTime=400 gate was disabled (=0) -- with it, Virtuoso rejects the big join queries with HTTP 500 'estimated execution time exceeds the limit' before executing (join-2-largest-result and others would not run at all); the 300s execution timeout still applies. 81/105 passed.
- MillenniumDB (benchmarked 2026-06-11) loaded the full 8,180,602,084 triples (matches QLever exactly). 67/105 passed, no HTTP errors -- slowest of the loaded engines on the heavy COUNT/join/string categories, but a clean complete load. COUNT(*) is not verifiable post-load on MDB (a full scan exceeds its own 300s timeout); load verified by import stats + the 327 GB index.
- Apache Jena loaded the full 8,186,371,175 triples but is the weakest at query time: 31/105 passed, 74 timeouts (no HTTP errors). Cold TDB2 page reads on the 655 GB index + no COUNT fastpath mean the COUNT-dominated SPARQLoscope queries overwhelmingly hit the 300s cap (geo-mean P=2 93.6s, median maxed at 300s).
