wrote benchmarks/sparqloscope/reports/dblp-core/REPORT.md (105 queries, 7 engines)
 dblp-core-20260610-204013); all 7 engines on dedicated m7a.4xlarge boxes, fractional ms precision. Geo mean (P=2, the SPARQLoscope paper's official aggregate; failed query = 2x the 180 s timeout): Fluree v4.1.2 18.5 ms, 105/105. QLever: 202 ms, 105/105. Virtuoso: 300 ms, 103/105 (chunked TTLP loading). MillenniumDB: 1664 ms, 103/105. Jena: 67.7 s, 34/105 (cold TDB cache). Oxigraph: 87.0 s, 39/105. Blazegraph: 333 s, 3/105. Standard DBLP-core (bibliography only, no OpenCitations), stable DROPS archive 2026-06-01 (~561.5M distinct triples). All engines NATIVE (no Docker).**

**Dataset:** 574,218,804 triples, 90 predicates (2026-06-01 (stable DROPS monthly archive)) · **Engines:** Fluree v4.1.2, QLever git 621cf31 (native), Oxigraph 0.5.8 (native, prebuilt binary), Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0 (built from source), Jena Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21), Blazegraph 2.1.6-RC (Java 11) · **Box:** AWS m7a.4xlarge (16c / 64 GB) · 1+3 runs, median, 180 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|
| passed | 105/105 | 105/105 | 39/105 | 103/105 | 103/105 | 34/105 | 3/105 |
| geo mean (P=2) | **21 ms (1.0×)** | 206 ms (10.0×) | 87.0 s (4198.9×) | 303 ms (14.6×) | 1,720 ms (83.0×) | 67.8 s (3269.8×) | 332.9 s (16063.1×) |
| geo mean (P=10) | **21 ms (1.0×)** | 206 ms (10.0×) | 239.3 s (11547.5×) | 312 ms (15.1×) | 1,774 ms (85.6×) | 201.2 s (9708.8×) | 1589.5 s (76706.1×) |
| geo mean (passed only) | **21 ms (1.0×)** | 206 ms (10.0×) | 7,868 ms (379.7×) | 264 ms (12.7×) | 1,551 ms (74.8×) | 2,071 ms (100.0×) | 23.2 s (1118.0×) |
| arith mean (passed only) | **254 ms (1.0×)** | 1,904 ms (7.5×) | 36.8 s (144.8×) | 8,020 ms (31.6×) | 12.3 s (48.5×) | 31.0 s (122.1×) | 23.2 s (91.3×) |
| median (passed only) | **29 ms (1.0×)** | 310 ms (10.7×) | 5,090 ms (175.5×) | 326 ms (11.2×) | 3,894 ms (134.3×) | 4,540 ms (156.6×) | 23.2 s (798.4×) |

_geo mean (P=2/P=10) is the SPARQLoscope paper's official aggregate: a failed or timed-out query counts as 2× / 10× the 180 s timeout. The passed-only rows average each engine's completed queries only, so they flatter engines with many failures._

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|
| 1.22× | 8.74× | 311.13× | 5.87× | 57.16× | 260.11× | 469.90× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph | fastest |
|---|--:|---|---|---|---|---|---|---|---|
| Dataset statistics | 6 | **2 ms** | 16 ms | — | 13.3 s | 15.6 s | — | — | Fluree |
| JOIN | 12 | **10 ms (1.0×)** | 118 ms (11.7×) | 298 ms (29.4×) | 43 ms (4.3×) | 150 ms (14.8×) | 684 ms (67.4×) | — | Fluree |
| OPTIONAL | 10 | **47 ms (1.0×)** | 512 ms (10.8×) | — | 229 ms (4.8×) | 7,566 ms (159.3×) | — | — | Fluree |
| MINUS | 10 | **51 ms (1.0×)** | 520 ms (10.2×) | 38.8 s (759.6×) | 215 ms (4.2×) | 6,316 ms (123.6×) | 103.8 s (2031.5×) | — | Fluree |
| EXISTS | 10 | **52 ms (1.0×)** | 713 ms (13.7×) | 173.3 s (3332.6×) | 217 ms (4.2×) | 6,390 ms (122.9×) | 7,651 ms (147.1×) | — | Fluree |
| UNION | 5 | **59 ms (1.0×)** | 483 ms (8.2×) | 100.3 s (1711.9×) | 384 ms (6.6×) | 7,263 ms (124.0×) | 14.0 s (238.3×) | — | Fluree |
| GROUP BY / aggregate | 16 | **11 ms (1.0×)** | 268 ms (24.2×) | 15.4 s (1390.9×) | 692 ms (62.6×) | 2,561 ms (231.6×) | 5,175 ms (467.9×) | — | Fluree |
| FILTER | 3 | **35 ms (1.0×)** | 90 ms (2.6×) | — | 1,310 ms (37.2×) | 2,407 ms (68.3×) | 26.4 s (749.6×) | — | Fluree |
| Numeric functions | 10 | **10 ms** | 81 ms | 5,034 ms | 28 ms | 280 ms | — | — | Fluree |
| Date functions | 3 | **4 ms** | 220 ms | 4,845 ms | 95 ms | 218 ms | 2,039 ms | 23.2 s | Fluree |
| String / REGEX | 11 | **99 ms (1.0×)** | 973 ms (9.8×) | — | 1,921 ms (19.3×) | 10.8 s (108.3×) | — | — | Fluree |
| Transitive paths | 4 | **1 ms** | 5 ms | 383 ms | 5 ms | 7 ms | 5 ms | — | Fluree |
| Result size / export | 5 | 95 ms (2.9×) | 43 ms (1.3×) | 5,207 ms (155.6×) | 298 ms (8.9×) | **33 ms (1.0×)** | 387 ms (11.6×) | — | MillenniumDB |

### 1c. Per query

| query | category | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **16 ms (1.0×)** | 5,164 ms (322.8×) | — | 1,383 ms (86.4×) | 14.4 s (902.8×) | — | — |
| `number-of-literals` | Dataset statistics | **1 ms** | 3,484 ms | — | 5,915 ms | 13.7 s | — | — |
| `number-of-objects` | Dataset statistics | **1 ms** | **1 ms** | — | — | — | — | — |
| `number-of-predicates` | Dataset statistics | **1 ms** | **1 ms** | — | 57.1 s | 22.4 s | — | — |
| `number-of-subjects` | Dataset statistics | 2 ms | **1 ms** | — | 177.9 s | — | — | — |
| `number-of-triples` | Dataset statistics | **0 ms** | 1 ms | — | 5,004 ms | 13.4 s | — | — |
| `join-2-large-large` | JOIN | **1 ms** | 350 ms | — | 921 ms | 6,917 ms | 80.4 s | — |
| `join-2-large-large-with-large-result` | JOIN | **24 ms (1.0×)** | 414 ms (17.2×) | — | 853 ms (35.5×) | 9,036 ms (376.5×) | 93.5 s (3895.7×) | — |
| `join-2-large-large-with-small-result` | JOIN | 59 ms | 20 ms | — | 17 ms | **5 ms** | 12.9 s | — |
| `join-2-large-small` | JOIN | **1 ms** | 5 ms | — | 2 ms | 2 ms | 8 ms | — |
| `join-2-largest-result` | JOIN | **25 ms (1.0×)** | 415 ms (16.6×) | — | 859 ms (34.4×) | 9,029 ms (361.2×) | 94.8 s (3793.1×) | — |
| `join-2-small-large` | JOIN | **1 ms** | 5 ms | — | 2 ms | 2 ms | 8 ms | — |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | **229 ms (1.0×)** | 2,587 ms (11.3×) | — | 7,458 ms (32.6×) | 27.6 s (120.6×) | — | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **129 ms (1.0×)** | 2,282 ms (17.7×) | — | 233 ms (1.8×) | 24.9 s (192.7×) | — | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | **1 ms** | 453 ms | — | **1 ms** | **1 ms** | 11 ms | — |
| `join-xlarge-star-on-small-predicates` | JOIN | **1 ms** | 19 ms | — | **1 ms** | **1 ms** | 10 ms | — |
| `multicolumn-join-large` | JOIN | 1,138 ms (2.0×) | 4,891 ms (8.6×) | — | **569 ms (1.0×)** | 16.5 s (29.0×) | 69.8 s (122.6×) | — |
| `multicolumn-join-small` | JOIN | 1 ms | 1 ms | 298 ms | 1 ms | **0 ms** | 5 ms | — |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **25 ms (1.0×)** | 1,232 ms (49.3×) | — | 1,005 ms (40.2×) | 12.4 s (497.8×) | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | 66 ms (3.3×) | 79 ms (4.0×) | — | **20 ms (1.0×)** | 2,398 ms (119.9×) | — | — |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | 55 ms (1.8×) | 39 ms (1.3×) | — | **30 ms (1.0×)** | 3,877 ms (129.2×) | — | — |
| `optional-join-3-chain-1` | OPTIONAL | **230 ms (1.0×)** | 2,278 ms (9.9×) | — | 2,878 ms (12.5×) | 27.7 s (120.5×) | — | — |
| `optional-join-3-chain-2` | OPTIONAL | **804 ms (1.0×)** | 8,150 ms (10.1×) | — | 2,972 ms (3.7×) | 65.1 s (80.9×) | — | — |
| `optional-join-3-star-1` | OPTIONAL | **143 ms (1.0×)** | 3,017 ms (21.1×) | — | 326 ms (2.3×) | 37.6 s (262.7×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **171 ms (1.0×)** | 1,721 ms (10.1×) | — | 352 ms (2.1×) | 20.9 s (122.4×) | — | — |
| `optional-join-large-large` | OPTIONAL | **142 ms (1.0×)** | 1,466 ms (10.3×) | — | 691 ms (4.9×) | 43.9 s (309.0×) | — | — |
| `optional-join-large-small` | OPTIONAL | **1 ms** | 463 ms | — | 491 ms | 42.7 s | — | — |
| `optional-join-small-large` | OPTIONAL | **1 ms** | 5 ms | — | 2 ms | 2 ms | — | — |
| `minus-join-2-large-large-with-large-result` | MINUS | **21 ms (1.0×)** | 425 ms (20.2×) | 110.3 s (5251.8×) | 1,011 ms (48.1×) | 8,774 ms (417.8×) | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | 27 ms (1.4×) | 48 ms (2.4×) | 8,674 ms (433.7×) | **20 ms (1.0×)** | 2,389 ms (119.5×) | — | — |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **26 ms (1.0×)** | 62 ms (2.4×) | 7,021 ms (270.0×) | 30 ms (1.2×) | 3,888 ms (149.5×) | — | — |
| `minus-join-3-chain-1` | MINUS | **223 ms (1.0×)** | 1,407 ms (6.3×) | — | 2,880 ms (12.9×) | 20.5 s (91.8×) | 103.8 s (465.5×) | — |
| `minus-join-3-chain-2` | MINUS | **2,443 ms (1.0×)** | 8,650 ms (3.5×) | — | 2,915 ms (1.2×) | 25.5 s (10.4×) | — | — |
| `minus-join-3-star-1` | MINUS | 1,707 ms (5.4×) | 2,120 ms (6.8×) | — | **314 ms (1.0×)** | 36.0 s (114.7×) | — | — |
| `minus-join-3-star-2` | MINUS | **75 ms (1.0×)** | 2,031 ms (27.1×) | — | 232 ms (3.1×) | 19.2 s (256.5×) | — | — |
| `minus-join-large-large` | MINUS | **118 ms (1.0×)** | 811 ms (6.9×) | 177.1 s (1500.5×) | 619 ms (5.2×) | 41.5 s (351.5×) | — | — |
| `minus-join-large-small` | MINUS | **1 ms** | 611 ms | 74.1 s | 464 ms | 41.3 s | — | — |
| `minus-join-small-large` | MINUS | **1 ms** | 44 ms | — | 2 ms | 2 ms | — | — |
| `exists-join-2-large-large-with-large-result` | EXISTS | **26 ms (1.0×)** | 789 ms (30.3×) | — | 957 ms (36.8×) | 9,071 ms (348.9×) | 79.0 s (3038.0×) | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | 26 ms (1.4×) | 60 ms (3.3×) | — | **18 ms (1.0×)** | 2,378 ms (132.1×) | 13.9 s (771.9×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **26 ms (1.0×)** | 60 ms (2.3×) | — | 31 ms (1.2×) | 3,894 ms (149.8×) | 14.0 s (540.2×) | — |
| `exists-join-3-chain-1` | EXISTS | **229 ms (1.0×)** | 3,693 ms (16.1×) | — | 12.0 s (52.3×) | 21.4 s (93.4×) | 170.0 s (742.5×) | — |
| `exists-join-3-chain-2` | EXISTS | **2,433 ms (1.0×)** | 10.2 s (4.2×) | — | 171.6 s (70.5×) | 25.9 s (10.6×) | — | — |
| `exists-join-3-star-1` | EXISTS | 1,616 ms (4.6×) | 2,607 ms (7.4×) | — | **352 ms (1.0×)** | 37.3 s (106.0×) | — | — |
| `exists-join-3-star-2` | EXISTS | **76 ms (1.0×)** | 2,412 ms (31.7×) | — | 240 ms (3.2×) | 19.8 s (260.4×) | — | — |
| `exists-join-large-large` | EXISTS | **120 ms (1.0×)** | 851 ms (7.1×) | — | 629 ms (5.2×) | 40.8 s (340.0×) | — | — |
| `exists-join-large-small` | EXISTS | **1 ms** | 470 ms | — | 2 ms | 40.5 s | — | — |
| `exists-join-small-large` | EXISTS | **1 ms** | 126 ms | 173.3 s | 2 ms | 2 ms | 10 ms | — |
| `union-constraint-filter-restrictive` | UNION | 1,297 ms (2.2×) | 944 ms (1.6×) | — | **582 ms (1.0×)** | 4,106 ms (7.1×) | 14.0 s (24.0×) | — |
| `union-constraint-from-star` | UNION | **119 ms (1.0×)** | 1,324 ms (11.1×) | — | 375 ms (3.2×) | 31.4 s (263.5×) | — | — |
| `union-constraint-large-join` | UNION | **203 ms (1.0×)** | 764 ms (3.8×) | — | 1,804 ms (8.9×) | 16.4 s (80.8×) | — | — |
| `union-constraint-small-join` | UNION | **22 ms (1.0×)** | 117 ms (5.3×) | — | 36 ms (1.6×) | 2,240 ms (101.8×) | — | — |
| `union-no-constraint` | UNION | **1 ms** | 235 ms | 100.3 s | 587 ms | 4,271 ms | — | — |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **1 ms** | 2,478 ms | 69.1 s | 11.3 s | 4,274 ms | 21.9 s | — |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **1 ms** | 12.9 s | 31.8 s | 36.1 s | 78.6 s | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 1,118 ms (1.1×) | **1,044 ms (1.0×)** | — | 2,902 ms (2.8×) | 6,752 ms (6.5×) | 30.1 s (28.8×) | — |
| `group-by-complex-aggregate` | GROUP BY / aggregate | **387 ms (1.0×)** | 1,962 ms (5.1×) | — | 39.3 s (101.7×) | 18.7 s (48.3×) | — | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | 16 ms (1.5×) | **11 ms (1.0×)** | 81.1 s (7376.4×) | 185 ms (16.8×) | 3,858 ms (350.7×) | — | — |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **161 ms (1.0×)** | 1,928 ms (12.0×) | 81.6 s (507.1×) | 6,776 ms (42.1×) | 28.0 s (174.1×) | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | 369 ms (5.5×) | 1,514 ms (22.6×) | — | **67 ms (1.0×)** | 6,529 ms (97.4×) | — | — |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | **59 ms (1.0×)** | 85 ms (1.4×) | 5,831 ms (98.8×) | 193 ms (3.3×) | 255 ms (4.3×) | 2,807 ms (47.6×) | — |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | **1 ms** | 2 ms | 4,461 ms | 6 ms | 229 ms | 2,646 ms | — |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **1 ms** | 79 ms | 4,661 ms | 78 ms | 246 ms | 2,507 ms | — |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **1 ms** | 79 ms | 4,706 ms | 80 ms | 264 ms | 3,048 ms | — |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | **43 ms (1.0×)** | 85 ms (2.0×) | 4,726 ms (109.9×) | 130 ms (3.0×) | 255 ms (5.9×) | 2,663 ms (61.9×) | — |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | **1 ms** | 2 ms | 18.9 s | 81 ms | 767 ms | — | — |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **1 ms** | 262 ms | — | 281 ms | 1,697 ms | — | — |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **1 ms** | 262 ms | — | 205 ms | 1,554 ms | — | — |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **48 ms (1.0×)** | 26.8 s (558.1×) | — | 161.9 s (3372.9×) | 58.6 s (1220.4×) | — | — |
| `filter-few-results` | FILTER | **147 ms (1.0×)** | 766 ms (5.2×) | — | 224 ms (1.5×) | 3,328 ms (22.6×) | 11.0 s (74.5×) | — |
| `filter-language-en` | FILTER | 2 ms | **1 ms** | — | 38.6 s | 823 ms | 63.7 s | — |
| `filter-many-results` | FILTER | **149 ms (1.0×)** | 963 ms (6.5×) | — | 260 ms (1.7×) | 5,091 ms (34.2×) | — | — |
| `numeric-abs` | Numeric functions | 45 ms (1.0×) | 189 ms (4.4×) | 5,742 ms (133.5×) | **43 ms (1.0×)** | 298 ms (6.9×) | — | — |
| `numeric-add` | Numeric functions | 45 ms (1.7×) | 259 ms (10.0×) | 5,186 ms (199.5×) | **26 ms (1.0×)** | 323 ms (12.4×) | — | — |
| `numeric-baseline` | Numeric functions | **43 ms (1.0×)** | 85 ms (2.0×) | 4,730 ms (110.0×) | 125 ms (2.9×) | 255 ms (5.9×) | — | — |
| `numeric-ceil` | Numeric functions | **45 ms (1.0×)** | 189 ms (4.2×) | 4,938 ms (109.7×) | 65 ms (1.4×) | 295 ms (6.6×) | — | — |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **1 ms** | 31 ms | 5,090 ms | 14 ms | 308 ms | — | — |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | **1 ms** | 5 ms | 4,874 ms | 3 ms | 236 ms | — | — |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | **1 ms** | 24 ms | 5,007 ms | 11 ms | 286 ms | — | — |
| `numeric-floor` | Numeric functions | **45 ms (1.0×)** | 188 ms (4.2×) | 4,977 ms (110.6×) | 65 ms (1.4×) | 297 ms (6.6×) | — | — |
| `numeric-greater` | Numeric functions | **1 ms** | 121 ms | 4,917 ms | 18 ms | 220 ms | — | — |
| `numeric-round` | Numeric functions | **45 ms (1.0×)** | 188 ms (4.2×) | 4,947 ms (109.9×) | 66 ms (1.5×) | 297 ms (6.6×) | — | — |
| `date-day` | Date functions | **1 ms** | 235 ms | 4,581 ms | 96 ms | 218 ms | 1,655 ms | 23.2 s |
| `date-month` | Date functions | **1 ms** | 235 ms | 4,504 ms | 97 ms | 218 ms | 2,477 ms | 23.3 s |
| `date-year` | Date functions | **49 ms (1.0×)** | 194 ms (4.0×) | 5,511 ms (112.5×) | 93 ms (1.9×) | 218 ms (4.4×) | 2,069 ms (42.2×) | 23.0 s (469.9×) |
| `regex-3` | String / REGEX | **570 ms (1.0×)** | 7,381 ms (12.9×) | — | 9,067 ms (15.9×) | 21.1 s (37.1×) | — | — |
| `regex-3-contains` | String / REGEX | **110 ms (1.0×)** | 6,897 ms (62.7×) | — | 1,554 ms (14.1×) | 2,893 ms (26.3×) | — | — |
| `regex-3-fixed` | String / REGEX | **423 ms (1.0×)** | 7,359 ms (17.4×) | — | 1,709 ms (4.0×) | 21.3 s (50.3×) | — | — |
| `regex-prefix-1` | String / REGEX | 168 ms | **7 ms** | — | 1,794 ms | 19.6 s | — | — |
| `regex-prefix-2` | String / REGEX | 29 ms | **4 ms** | — | 1,721 ms | 20.8 s | — | — |
| `regex-prefix-3` | String / REGEX | 11 ms | **2 ms** | — | 1,676 ms | 21.3 s | — | — |
| `strafter` | String / REGEX | **130 ms (1.0×)** | 10.9 s (84.1×) | — | 1,703 ms (13.1×) | 34.5 s (265.1×) | — | — |
| `strbefore` | String / REGEX | **118 ms (1.0×)** | 10.1 s (85.4×) | — | 1,568 ms (13.3×) | 11.9 s (100.9×) | — | — |
| `strends` | String / REGEX | **97 ms (1.0×)** | 6,721 ms (69.3×) | — | 1,558 ms (16.1×) | 2,919 ms (30.1×) | — | — |
| `strlen` | String / REGEX | **105 ms (1.0×)** | 7,099 ms (67.6×) | — | 1,629 ms (15.5×) | 5,655 ms (53.9×) | — | — |
| `strstarts` | String / REGEX | **42 ms (1.0×)** | 6,700 ms (159.5×) | — | 1,553 ms (37.0×) | 2,925 ms (69.6×) | — | — |
| `transitive-path-large-join-and-plus` | Transitive paths | **0 ms** | 682 ms | — | 137 ms | 2,897 ms | — | — |
| `transitive-path-plus` | Transitive paths | **1 ms** | **1 ms** | 252 ms | — | **1 ms** | — | — |
| `transitive-path-plus-fixed-subject` | Transitive paths | **1 ms** | **1 ms** | 902 ms | **1 ms** | **1 ms** | — | — |
| `transitive-path-small-join-and-plus` | Transitive paths | 1 ms | 1 ms | 248 ms | 1 ms | **0 ms** | 5 ms | — |
| `result-size-large` | Result size / export | 713 ms (2.3×) | **310 ms (1.0×)** | 180.0 s (580.6×) | 17.1 s (55.1×) | 345 ms (1.1×) | 155.5 s (501.7×) | — |
| `result-size-medium` | Result size / export | 74 ms (2.1×) | 37 ms (1.1×) | 48.4 s (1383.9×) | 1,555 ms (44.4×) | **35 ms (1.0×)** | 6,033 ms (172.4×) | — |
| `result-size-small` | Result size / export | 7 ms | 2 ms | 488 ms | 5 ms | **1 ms** | 6 ms | — |
| `result-size-tiny` | Result size / export | 3 ms | 2 ms | 5 ms | 1 ms | **0 ms** | 4 ms | — |
| `result-size-xlarge` | Result size / export | 7,115 ms (2.2×) | **3,194 ms (1.0×)** | 180.0 s (56.4×) | 17.9 s (5.6×) | 3,472 ms (1.1×) | — | — |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 681 s | 0.82 M tr/s | ? | ? | fluree create dblp --from dblp.nt on the m7a.4xlarge box; 561,544,658 distinct triples. Import is ~25-33% slower than the v4.0.6 baseline (512 s / 1.10 M tr/s) — a known carried regression since v4.0.7, in the import path only; query latency is unaffected (see status). Peak RAM / index size not re-measured for v4.1.2 (v4.0.6: 20.1 GB peak, 27 GB index). |
| QLever | 521 s | 1.08 M tr/s | 20.8 GB | 9.4 GB | qlever index (native), parallel parse @ 2.3 M/s. in-memory-compressed vocab, num-triples-per-batch 1M (matches the paper). Native on the host needed two things Docker masked: ulimit -n raised to 1048576 (533 partial vocabs) and --stxxl-memory 20G (permutation merge). QLever counts 561,477,456 distinct triples (Fluree 561,544,658; +0.012% delta, different exact-dup handling). |
| Oxigraph | 572 s | 0.98 M tr/s | n/a | 43 GB | oxigraph load --format nt --lenient. Till-ready = 329 s parse @ 1.70 M t/s + ~243 s RocksDB compaction. Loaded 561,477,456 triples. No COUNT fastpath. 39/105 queries completed within 180 s; 66/105 timed out. |
| Virtuoso | ~700 s | ~0.8 M tr/s | ~28 GB | 17 GB | split -l 50000 + 8 parallel TTLP threads + checkpoint. Loaded 561,483,067 triples, 90 predicates. number-of-objects timed out (>180 s full distinct scan); transitive-path-plus returned engine error. 103/105 completed. |
| MillenniumDB | 1241 s | 0.45 M tr/s | ~40 GB | 21 GB | mdb import --format ttl --buffer-strings 20GB --buffer-tensors 20GB (scaled down from the paper's 40GB+40GB=80GB, which OOMs a 64GB box). Loaded 561,477,456 triples, 90 predicates. number-of-objects/number-of-subjects timed out (>180 s full distinct scans); 103/105 completed. |
| Jena | 7471 s | 0.075 M tr/s | ~33 GB | 54 GB | tdb2.xloader (external-sort bulk loader). Loaded from 574.2M-line .nt. TDB index pre-built; Fuseki started cold for benchmark. Cold 54GB index + no COUNT fastpath caused 71/105 timeouts; only 34/105 completed. |
| Blazegraph | 9950 s | 0.056 M tr/s | n/a | 43 GB | REQUIRED skolemization: default load silently drops all blank-node triples (239M/561M). Skolemizing _:label -> IRI then DataLoader gave the full 561,544,658. +~33 min skolemize (sed) before the 9950 s load. |

- **QLever phases:** parse 247 s @ 2.3 M/s + vocab merge + convert + sort/permutations; total 521 s

- **Oxigraph phases:** parse 329 s @ 1.70 M t/s + RocksDB compaction ~243 s = 572 s till-ready

- **Virtuoso phases:** chunked TTLP load + checkpoint = ~700 s till-ready

- **MillenniumDB phases:** single-pass import 1241 s

- **Jena phases:** nodes 1217 s + terms + data + per-permutation index build = 7471 s till-ready

- **Blazegraph phases:** skolemize ~33 min + DataLoader 9950 s (2.76 h) = ~3.3 h till-ready

## 4. Environment & dataset

- **Dataset:** DBLP-core (bibliography only) — Standard DBLP RDF bibliography, no OpenCitations citations — DROPS monthly archive 2026-06-01
  - source: https://drops.dagstuhl.de/storage/artifacts/dblp/rdf/2026/dblp-2026-06-01.nt.gz
  - version: 2026-06-01 (stable DROPS monthly archive) · SHA-256 `6a1edc1b7aebcd7a581bc4313243029952af4af0fbf900e4126a72d6deb92309`
  - **574,218,804 triples**, 90 predicates, ? subjects, ? objects · on-disk 4.73 GB .nt.gz (5,083,386,634 bytes); ~73.5 GB uncompressed .nt
- **Hardware:** AWS m7a.4xlarge — AMD EPYC (Zen 4), no-SMT, 16 cores, 64 GB RAM, 250 GB gp3 (6000 IOPS / 500 MB/s), Ubuntu 24.04
- **Method:** 1 warmup + 3 timed runs, median reported, 180 s timeout, results as `text/tab-separated-values`
  - All engines NATIVE (no Docker). Timeout 180 s per query per the SPARQLoscope DBLP spec (docs/Qleverfile.dblp TIMEOUT=180s), with a per-query 180 s wall budget (a query that takes ~180 s for one run is measured once, not 3x). Fluree/QLever/Virtuoso were initially run at a 300 s cap but NO query fell in the 180-300 s window (max passing: Fluree 12 s, QLever 37 s, Virtuoso 154 s), so their results are identical to a 180 s run and were not re-run; Oxigraph and Jena ran at 180 s. QLever result cache disabled + cleared before each run so it re-executes (matches Fluree/Virtuoso/Jena, which have no result cache); Oxigraph runs single-shot, memory-capped, per-query restart-on-failure.

| engine | version | config |
|---|---|---|
| Fluree | v4.1.2 | Server cache auto (~31.5 GB); inline-indexed ledger. Built from source (branch feature/warm-on-write-reindex-cache @ 25d8c28f — warm-on-write read cache + filtered-DELETE staging fix; binary reports 'fluree 4.1.1', pre-release v4.1.2). Retains the v4.0.6 metadata-driven fast paths (literals, subjects, objects, MIN/MAX string, COUNT DISTINCT) and algebraic aggregate identities. Query perf flat-to-better vs v4.0.6 (geo 18.5 vs 19.4 ms, 105/105). |
| QLever | git 621cf31 (native) (`621cf31 (native binaries from adfreiburg/qlever:latest image, run directly — no Docker)`) | native; MEMORY_FOR_QUERIES 26G, CACHE_MAX_SIZE 6G (disabled for the benchmark), in-memory-compressed vocab, TIMEOUT 300s — matches ad-freiburg/sparqloscope docs/Qleverfile.dblp |
| Oxigraph | 0.5.8 (native, prebuilt binary) (`oxigraph_v0.5.8_x86_64_linux_gnu (GitHub release)`) | serve-read-only; systemd MemoryMax 52G; no result cache; no server-side query timeout (issue #1336). Sweep methodology DEVIATES from the other engines: warmup 0 + 1 timed run, 180 s timeout, memory-capped with per-query restart-on-failure (mirrors ad-freiburg/sparqloscope util/oxigraph-helper.sh). RocksDB-backed. |
| Virtuoso | 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7) (`07.20.3229`) | 32 GB profile: NumberOfBuffers 2,720,000 (~21 GB), MaxDirtyBuffers 2,000,000, MaxQueryExecutionTime 300 s, ResultSetMaxRows 10M. Data in named graph <https://dblp.org>; queries sent with default-graph-uri. Ubuntu apt 07.20.3229 has a broken ld_dir; data loaded via chunked TTLP(file_to_string(chunk)) in parallel. |
| MillenniumDB | v1.0.0 (built from source) (`github.com/MillenniumDB/MillenniumDB main`) | native; versioned-buffer 22GB, strings-static 4GB, strings-dynamic 4GB; body POST; no result cache. Built on its own m7a.4xlarge (16c/64GB), dblp-core pulled from S3. |
| Jena | Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21) (`6.1.0`) | TDB2 + Fuseki; JVM_ARGS -Xmx32g; body POST; no result cache. Fuseki started cold for benchmark run (no JVM warmup, no OS page cache warmup of 54GB index). |
| Blazegraph | 2.1.6-RC (Java 11) (`BLAZEGRAPH_2_1_6_RC`) | native jar; offline DataLoader on a SKOLEMIZED .nt (blank nodes rewritten to IRIs — required: default load silently drops ALL blank-node triples, 239M/561M); served with -Xmx16g; web.xml queryTimeout 180000; queries via --post-form. Dedicated m7a.4xlarge. |

**Caveats**
- Run 2026-06-11 (dblp-core-20260610-204013): all 7 engines on dedicated m7a.4xlarge boxes, fractional ms precision, all engines NATIVE (no Docker).
- Virtuoso: loaded via chunked TTLP because ld_dir is broken in Ubuntu apt 07.20.3229. We also tried rdf_loader_run in an earlier setup pass; chunked TTLP gave clearly better query times (loading method affects B-tree organization), so this run uses it. Earlier passes ran on a coarser-precision harness, so no like-for-like timing comparison is published.
- Jena: 34/105 completed. Fuseki started cold for the benchmark; a cold 54GB index on a 64GB box (32GB JVM heap) causes many heavy queries to time out. In an earlier setup pass with a warm OS page cache Jena completed substantially more queries (69/105), so treat the completion count as cache-state sensitive.
- NOT bit-comparable to the published SPARQLoscope table: that used DBLP 2024-04-01 / 2025-04-01 (~390-502M); this is the 2026-06-01 core archive (574.2M raw lines, ~561.5M distinct).
- Triple-count delta: Fluree 561,544,658 vs QLever 561,477,456 distinct (+0.012%) — different exact-duplicate handling on import; both agree on 90 predicates.
- Oxigraph: 39/105 completed. Sweep uses documented deviation (1 run, 180 s, memory-capped, per-query restart); not directly comparable to warmup+median-of-3 engines.
- Absolute times are this-box-only (m7a.4xlarge, 16c/64GB).
- Scope: this run compares query completion and latency, not result-set equivalence.
