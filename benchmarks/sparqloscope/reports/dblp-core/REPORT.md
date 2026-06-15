# SPARQLoscope benchmark — DBLP-core (bibliography only)

> **Run 2026-06-11, all 7 engines on dedicated AWS m7a.4xlarge boxes (run dblp-core-20260610-204013), fractional ms timing precision. Fluree is v4.0.6. Standard DBLP-core (bibliography only, no OpenCitations), stable DROPS archive 2026-06-01 (574.2M raw N-Triples lines; ~561.5M distinct triples after dedup). All seven engines run NATIVE (no Docker); QLever config matches ad-freiburg/sparqloscope docs/Qleverfile.dblp. Engine-vs-engine on one box; NOT bit-comparable to the paper's 2024/2025 dumps.**

**Dataset:** 574,218,804 raw N-Triples lines (~561.5M distinct after dedup), 90 predicates (2026-06-01 (stable DROPS monthly archive)) · **Engines:** Fluree v4.0.6, QLever git 621cf31 (native), Oxigraph 0.5.8 (native, prebuilt binary), Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0 (built from source), Jena Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21), Blazegraph 2.1.6-RC (Java 11) · **Box:** AWS m7a.4xlarge (16c / 64 GB) · 1+3 runs, median, 180 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|
| passed | 105/105 | 105/105 | 39/105 | 103/105 | 103/105 | 34/105 | 3/105 |
| geo mean (P=2) | **19.4 ms (1.0×)** | 202 ms (10.4×) | 87.0 s (4486×) | 300 ms (15.4×) | 1,664 ms (86×) | 67.7 s (3487×) | 333 s (17158×) |
| geo mean (P=10) | **19.4 ms (1.0×)** | 202 ms (10.4×) | 239.4 s (12338×) | 309 ms (15.9×) | 1,716 ms (88×) | 200.9 s (10355×) | 1,590 s (81934×) |
| geo mean (passed only) | **19.4 ms (1.0×)** | 202 ms (10.4×) | 7,875 ms (406×) | 261 ms (13.5×) | 1,499 ms (77×) | 2,062 ms (106×) | 23.0 s (1187×) |
| arith mean (passed only) | **251 ms (1.0×)** | 1,904 ms (7.6×) | 36.8 s (147×) | 8,020 ms (32.0×) | 12.3 s (49.0×) | 31.0 s (124×) | 23.0 s (91.6×) |
| median (passed only) | **41 ms (1.0×)** | 310 ms (7.6×) | 5,090 ms (124×) | 326 ms (7.9×) | 3,894 ms (95×) | 6,033 ms (147×) | 23,041 ms (562×) |

_geo mean (P=2/P=10) is the SPARQLoscope paper's official aggregate: a failed or
timed-out query counts as 2× / 10× the 180 s timeout. The passed-only rows average each
engine's completed queries only, so they flatter engines with many failures._

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|
| 1.0× | 10.45× | 1160× | 12.68× | 73.46× | 184× | 4277× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph | fastest |
|---|--:|---|---|---|---|---|---|---|---|
| Dataset statistics | 6 | **2 ms** | 14 ms (8.9×) | — | 13,297 ms (8634.8×) | 15,599 ms (10129.3×) | — | — | Fluree |
| JOIN | 12 | **10 ms** | 116 ms (12.1×) | 298 ms (31.3×) | 42 ms (4.4×) | 138 ms (14.4×) | 681 ms (71.4×) | — | Fluree |
| OPTIONAL | 10 | **45 ms** | 508 ms (11.2×) | — | 228 ms (5.0×) | 7,423 ms (163.5×) | — | — | Fluree |
| MINUS | 10 | **49 ms** | 519 ms (10.6×) | 38,813 ms (790.2×) | 215 ms (4.4×) | 6,337 ms (129.0×) | 103,805 ms (2113.3×) | — | Fluree |
| EXISTS | 10 | **49 ms** | 712 ms (14.4×) | 173,269 ms (3505.4×) | 214 ms (4.3×) | 6,482 ms (131.1×) | 7,636 ms (154.5×) | — | Fluree |
| UNION | 5 | **54 ms** | 483 ms (9.0×) | 100,270 ms (1868.9×) | 383 ms (7.1×) | 7,263 ms (135.4×) | 13,957 ms (260.2×) | — | Fluree |
| GROUP BY / aggregate | 16 | **9 ms** | 272 ms (30.3×) | 15,382 ms (1715.8×) | 693 ms (77.3×) | 2,562 ms (285.8×) | 5,175 ms (577.3×) | — | Fluree |
| FILTER | 3 | **56 ms** | 87 ms (1.6×) | — | 1,310 ms (23.4×) | 2,407 ms (42.9×) | 26,425 ms (471.4×) | — | Fluree |
| Numeric functions | 10 | **10 ms** | 82 ms (8.1×) | 5,034 ms (499.9×) | 28 ms (2.8×) | 280 ms (27.8×) | — | — | Fluree |
| Date functions | 3 | **5 ms** | 220 ms (41.0×) | 4,844 ms (902.2×) | 95 ms (17.7×) | 218 ms (40.7×) | 2,039 ms (379.8×) | 22,965 ms (4276.8×) | Fluree |
| String / REGEX | 11 | **98 ms** | 957 ms (9.8×) | — | 1,921 ms (19.6×) | 10,759 ms (109.9×) | — | — | Fluree |
| Transitive paths | 4 | **1 ms** | 4 ms (7.6×) | 384 ms (646.1×) | 5 ms (8.1×) | 5 ms (8.7×) | 5 ms (7.7×) | — | Fluree |
| Result size / export | 5 | 80 ms (2.9×) | 42 ms (1.5×) | 5,239 ms (193.4×) | 295 ms (10.9×) | **27 ms** | 386 ms (14.3×) | — | MillenniumDB |

_A **—** means the engine returned no result for that whole category within the
180 s timeout (every query in it timed out or errored), so no category geo mean can
be computed — not "not run." Multipliers are vs the fastest engine on each query._

### 1c. Per query

| query | category | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **41 ms** | 5,164 ms (125.8×) | — | 1,383 ms (33.7×) | 14,445 ms (351.8×) | — | — |
| `number-of-literals` | Dataset statistics | **1 ms** | 3,484 ms (6049.2×) | — | 5,915 ms (10269.3×) | 13,689 ms (23764.8×) | — | — |
| `number-of-objects` | Dataset statistics | 1 ms (1.7×) | **1 ms** | — | — | — | — | — |
| `number-of-predicates` | Dataset statistics | **1 ms** | 1 ms (1.4×) | — | 57,081 ms (111487.1×) | 22,405 ms (43759.8×) | — | — |
| `number-of-subjects` | Dataset statistics | 1 ms (1.6×) | **1 ms** | — | 177,869 ms (217443.9×) | — | — | — |
| `number-of-triples` | Dataset statistics | **1 ms** | 1 ms (1.3×) | — | 5,004 ms (8136.8×) | 13,363 ms (21728.6×) | — | — |
| `join-2-large-large` | JOIN | **1 ms** | 350 ms (632.7×) | — | 921 ms (1664.7×) | 6,917 ms (12508.9×) | 80,371 ms (145335.7×) | — |
| `join-2-large-large-with-large-result` | JOIN | **25 ms** | 414 ms (16.7×) | — | 853 ms (34.4×) | 9,036 ms (363.8×) | 93,497 ms (3764.7×) | — |
| `join-2-large-large-with-small-result` | JOIN | 58 ms (12.2×) | 20 ms (4.2×) | — | 17 ms (3.6×) | **5 ms** | 12,856 ms (2694.1×) | — |
| `join-2-large-small` | JOIN | **1 ms** | 5 ms (7.5×) | — | 2 ms (3.0×) | 2 ms (3.3×) | 8 ms (13.6×) | — |
| `join-2-largest-result` | JOIN | **25 ms** | 415 ms (16.6×) | — | 859 ms (34.3×) | 9,029 ms (360.3×) | 94,827 ms (3783.5×) | — |
| `join-2-small-large` | JOIN | **1 ms** | 5 ms (7.3×) | — | 2 ms (3.0×) | 2 ms (3.9×) | 8 ms (12.4×) | — |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | **228 ms** | 2,587 ms (11.4×) | — | 7,458 ms (32.8×) | 27,614 ms (121.3×) | — | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **130 ms** | 2,282 ms (17.5×) | — | 233 ms (1.8×) | 24,863 ms (190.5×) | — | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | 1 ms (1.1×) | 453 ms (545.0×) | — | **1 ms** | 1 ms (1.0×) | 11 ms (13.0×) | — |
| `join-xlarge-star-on-small-predicates` | JOIN | 4 ms (5.4×) | 19 ms (24.9×) | — | 1 ms (1.2×) | **1 ms** | 10 ms (13.7×) | — |
| `multicolumn-join-large` | JOIN | 1,121 ms (2.0×) | 4,891 ms (8.6×) | — | **569 ms** | 16,526 ms (29.1×) | 69,778 ms (122.7×) | — |
| `multicolumn-join-small` | JOIN | 1 ms (1.3×) | 1 ms (1.9×) | 298 ms (610.1×) | 1 ms (1.8×) | **0 ms** | 5 ms (9.7×) | — |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **27 ms** | 1,232 ms (46.4×) | — | 1,005 ms (37.9×) | 12,444 ms (469.0×) | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | 66 ms (3.4×) | 79 ms (4.0×) | — | **20 ms** | 2,398 ms (122.2×) | — | — |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | 56 ms (1.9×) | 39 ms (1.3×) | — | **30 ms** | 3,877 ms (129.5×) | — | — |
| `optional-join-3-chain-1` | OPTIONAL | **228 ms** | 2,278 ms (10.0×) | — | 2,878 ms (12.6×) | 27,708 ms (121.6×) | — | — |
| `optional-join-3-chain-2` | OPTIONAL | **814 ms** | 8,150 ms (10.0×) | — | 2,972 ms (3.7×) | 65,073 ms (80.0×) | — | — |
| `optional-join-3-star-1` | OPTIONAL | **145 ms** | 3,017 ms (20.8×) | — | 326 ms (2.2×) | 37,567 ms (258.4×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **177 ms** | 1,721 ms (9.7×) | — | 352 ms (2.0×) | 20,938 ms (118.5×) | — | — |
| `optional-join-large-large` | OPTIONAL | **145 ms** | 1,466 ms (10.1×) | — | 691 ms (4.8×) | 43,881 ms (302.5×) | — | — |
| `optional-join-large-small` | OPTIONAL | **1 ms** | 463 ms (660.9×) | — | 491 ms (701.3×) | 42,688 ms (60982.2×) | — | — |
| `optional-join-small-large` | OPTIONAL | **1 ms** | 5 ms (5.9×) | — | 2 ms (2.5×) | 2 ms (2.1×) | — | — |
| `minus-join-2-large-large-with-large-result` | MINUS | **22 ms** | 425 ms (19.6×) | 110,288 ms (5093.7×) | 1,011 ms (46.7×) | 8,774 ms (405.2×) | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | 28 ms (1.4×) | 48 ms (2.4×) | 8,674 ms (436.7×) | **20 ms** | 2,389 ms (120.3×) | — | — |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **27 ms** | 62 ms (2.3×) | 7,021 ms (264.8×) | 30 ms (1.1×) | 3,888 ms (146.6×) | — | — |
| `minus-join-3-chain-1` | MINUS | **221 ms** | 1,407 ms (6.4×) | — | 2,880 ms (13.0×) | 20,481 ms (92.5×) | 103,805 ms (469.1×) | — |
| `minus-join-3-chain-2` | MINUS | **2,386 ms** | 8,650 ms (3.6×) | — | 2,915 ms (1.2×) | 25,495 ms (10.7×) | — | — |
| `minus-join-3-star-1` | MINUS | 1,690 ms (5.4×) | 2,120 ms (6.8×) | — | **314 ms** | 36,015 ms (114.7×) | — | — |
| `minus-join-3-star-2` | MINUS | **79 ms** | 2,031 ms (25.8×) | — | 232 ms (2.9×) | 19,235 ms (244.3×) | — | — |
| `minus-join-large-large` | MINUS | **121 ms** | 811 ms (6.7×) | 177,055 ms (1462.1×) | 619 ms (5.1×) | 41,474 ms (342.5×) | — | — |
| `minus-join-large-small` | MINUS | **1 ms** | 611 ms (801.8×) | 74,070 ms (97205.2×) | 464 ms (609.1×) | 41,342 ms (54255.0×) | — | — |
| `minus-join-small-large` | MINUS | **1 ms** | 44 ms (55.1×) | — | 2 ms (2.5×) | 2 ms (2.6×) | — | — |
| `exists-join-2-large-large-with-large-result` | EXISTS | **23 ms** | 789 ms (34.0×) | — | 957 ms (41.3×) | 9,071 ms (391.6×) | 78,988 ms (3409.8×) | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | 26 ms (1.5×) | 60 ms (3.3×) | — | **18 ms** | 2,378 ms (131.5×) | 13,894 ms (768.3×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **26 ms** | 60 ms (2.3×) | — | 31 ms (1.2×) | 3,894 ms (147.0×) | 14,046 ms (530.3×) | — |
| `exists-join-3-chain-1` | EXISTS | **225 ms** | 3,693 ms (16.4×) | — | 11,977 ms (53.1×) | 21,380 ms (94.9×) | 170,027 ms (754.3×) | — |
| `exists-join-3-chain-2` | EXISTS | **2,417 ms** | 10,181 ms (4.2×) | — | 171,574 ms (71.0×) | 25,880 ms (10.7×) | — | — |
| `exists-join-3-star-1` | EXISTS | 1,606 ms (4.6×) | 2,607 ms (7.4×) | — | **352 ms** | 37,310 ms (106.0×) | — | — |
| `exists-join-3-star-2` | EXISTS | **80 ms** | 2,412 ms (30.0×) | — | 240 ms (3.0×) | 19,792 ms (246.1×) | — | — |
| `exists-join-large-large` | EXISTS | **118 ms** | 851 ms (7.2×) | — | 629 ms (5.3×) | 40,799 ms (346.7×) | — | — |
| `exists-join-large-small` | EXISTS | **1 ms** | 470 ms (575.0×) | — | 2 ms (2.3×) | 40,516 ms (49591.3×) | — | — |
| `exists-join-small-large` | EXISTS | **1 ms** | 126 ms (159.1×) | 173,269 ms (218498.2×) | 2 ms (2.3×) | 2 ms (2.9×) | 10 ms (12.5×) | — |
| `union-constraint-filter-restrictive` | UNION | 1,246 ms (2.1×) | 944 ms (1.6×) | — | **582 ms** | 4,106 ms (7.1×) | 13,957 ms (24.0×) | — |
| `union-constraint-from-star` | UNION | **119 ms** | 1,324 ms (11.2×) | — | 375 ms (3.2×) | 31,362 ms (264.5×) | — | — |
| `union-constraint-large-join` | UNION | **208 ms** | 764 ms (3.7×) | — | 1,804 ms (8.7×) | 16,409 ms (79.0×) | — | — |
| `union-constraint-small-join` | UNION | **23 ms** | 117 ms (5.2×) | — | 36 ms (1.6×) | 2,240 ms (99.3×) | — | — |
| `union-no-constraint` | UNION | **1 ms** | 235 ms (365.6×) | 100,270 ms (156183.6×) | 587 ms (914.0×) | 4,271 ms (6651.9×) | — | — |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **1 ms** | 2,478 ms (2881.7×) | 69,131 ms (80384.9×) | 11,260 ms (13092.6×) | 4,274 ms (4970.2×) | 21,884 ms (25447.1×) | — |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **1 ms** | 12,907 ms (16442.4×) | 31,818 ms (40532.2×) | 36,078 ms (45959.4×) | 78,634 ms (100171.2×) | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 1,096 ms (1.0×) | **1,044 ms** | — | 2,902 ms (2.8×) | 6,752 ms (6.5×) | 30,053 ms (28.8×) | — |
| `group-by-complex-aggregate` | GROUP BY / aggregate | **375 ms** | 1,962 ms (5.2×) | — | 39,342 ms (105.0×) | 18,675 ms (49.9×) | — | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | 16 ms (1.5×) | **11 ms** | 81,140 ms (7693.2×) | 185 ms (17.6×) | 3,858 ms (365.8×) | — | — |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **155 ms** | 1,928 ms (12.4×) | 81,642 ms (526.5×) | 6,776 ms (43.7×) | 28,028 ms (180.8×) | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | 361 ms (5.4×) | 1,514 ms (22.4×) | — | **67 ms** | 6,529 ms (96.8×) | — | — |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | **59 ms** | 85 ms (1.4×) | 5,831 ms (98.7×) | 193 ms (3.3×) | 255 ms (4.3×) | 2,807 ms (47.5×) | — |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | **1 ms** | 2 ms (4.1×) | 4,461 ms (8023.3×) | 6 ms (10.7×) | 229 ms (412.7×) | 2,646 ms (4759.6×) | — |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **1 ms** | 79 ms (134.3×) | 4,661 ms (7913.1×) | 78 ms (133.3×) | 246 ms (417.4×) | 2,507 ms (4255.8×) | — |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **1 ms** | 79 ms (117.6×) | 4,706 ms (7003.0×) | 80 ms (119.2×) | 264 ms (393.4×) | 3,048 ms (4536.4×) | — |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | **43 ms** | 85 ms (2.0×) | 4,726 ms (110.4×) | 130 ms (3.0×) | 255 ms (6.0×) | 2,663 ms (62.2×) | — |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | **1 ms** | 2 ms (4.0×) | 18,876 ms (32656.8×) | 81 ms (140.2×) | 767 ms (1326.7×) | — | — |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **1 ms** | 262 ms (384.2×) | — | 281 ms (411.7×) | 1,697 ms (2485.2×) | — | — |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **1 ms** | 262 ms (391.1×) | — | 205 ms (306.2×) | 1,554 ms (2315.2×) | — | — |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **49 ms** | 26,789 ms (551.3×) | — | 161,898 ms (3331.9×) | 58,578 ms (1205.6×) | — | — |
| `filter-few-results` | FILTER | **142 ms** | 766 ms (5.4×) | — | 224 ms (1.6×) | 3,328 ms (23.5×) | 10,954 ms (77.2×) | — |
| `filter-language-en` | FILTER | 9 ms (9.5×) | **1 ms** | — | 38,569 ms (42949.7×) | 823 ms (916.4×) | 63,745 ms (70985.4×) | — |
| `filter-many-results` | FILTER | **145 ms** | 963 ms (6.6×) | — | 260 ms (1.8×) | 5,091 ms (35.1×) | — | — |
| `numeric-abs` | Numeric functions | 44 ms (1.0×) | 189 ms (4.4×) | 5,742 ms (133.3×) | **43 ms** | 298 ms (6.9×) | — | — |
| `numeric-add` | Numeric functions | 45 ms (1.7×) | 259 ms (9.9×) | 5,186 ms (198.4×) | **26 ms** | 323 ms (12.4×) | — | — |
| `numeric-baseline` | Numeric functions | **43 ms** | 85 ms (2.0×) | 4,730 ms (110.9×) | 125 ms (2.9×) | 255 ms (6.0×) | — | — |
| `numeric-ceil` | Numeric functions | **44 ms** | 189 ms (4.3×) | 4,938 ms (112.8×) | 65 ms (1.5×) | 295 ms (6.7×) | — | — |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **1 ms** | 31 ms (27.3×) | 5,090 ms (4488.5×) | 14 ms (12.1×) | 308 ms (271.2×) | — | — |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | **1 ms** | 5 ms (4.9×) | 4,874 ms (4467.5×) | 3 ms (3.1×) | 236 ms (216.1×) | — | — |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | **1 ms** | 24 ms (21.3×) | 5,007 ms (4522.7×) | 11 ms (9.6×) | 286 ms (258.6×) | — | — |
| `numeric-floor` | Numeric functions | **44 ms** | 188 ms (4.3×) | 4,977 ms (112.9×) | 65 ms (1.5×) | 297 ms (6.7×) | — | — |
| `numeric-greater` | Numeric functions | **1 ms** | 121 ms (110.6×) | 4,917 ms (4486.1×) | 18 ms (16.1×) | 220 ms (200.6×) | — | — |
| `numeric-round` | Numeric functions | **44 ms** | 188 ms (4.3×) | 4,947 ms (112.9×) | 66 ms (1.5×) | 297 ms (6.8×) | — | — |
| `date-day` | Date functions | **2 ms** | 235 ms (126.4×) | 4,581 ms (2466.7×) | 96 ms (51.4×) | 218 ms (117.5×) | 1,655 ms (891.0×) | 22,803 ms (12279.3×) |
| `date-month` | Date functions | **2 ms** | 235 ms (144.6×) | 4,504 ms (2774.8×) | 97 ms (59.8×) | 218 ms (134.5×) | 2,477 ms (1526.1×) | 23,051 ms (14202.5×) |
| `date-year` | Date functions | **51 ms** | 194 ms (3.8×) | 5,511 ms (107.3×) | 93 ms (1.8×) | 218 ms (4.3×) | 2,069 ms (40.3×) | 23,041 ms (448.6×) |
| `regex-3` | String / REGEX | **482 ms** | 7,381 ms (15.3×) | — | 9,067 ms (18.8×) | 21,136 ms (43.9×) | — | — |
| `regex-3-contains` | String / REGEX | **110 ms** | 6,897 ms (62.5×) | — | 1,554 ms (14.1×) | 2,893 ms (26.2×) | — | — |
| `regex-3-fixed` | String / REGEX | **481 ms** | 7,359 ms (15.3×) | — | 1,709 ms (3.6×) | 21,262 ms (44.2×) | — | — |
| `regex-prefix-1` | String / REGEX | 155 ms (23.1×) | **7 ms** | — | 1,794 ms (267.1×) | 19,565 ms (2913.1×) | — | — |
| `regex-prefix-2` | String / REGEX | 31 ms (7.7×) | **4 ms** | — | 1,721 ms (434.2×) | 20,806 ms (5250.1×) | — | — |
| `regex-prefix-3` | String / REGEX | 10 ms (5.8×) | **2 ms** | — | 1,676 ms (951.6×) | 21,332 ms (12113.3×) | — | — |
| `strafter` | String / REGEX | **129 ms** | 10,927 ms (84.8×) | — | 1,703 ms (13.2×) | 34,461 ms (267.4×) | — | — |
| `strbefore` | String / REGEX | **117 ms** | 10,074 ms (86.1×) | — | 1,568 ms (13.4×) | 11,908 ms (101.8×) | — | — |
| `strends` | String / REGEX | **97 ms** | 6,721 ms (69.5×) | — | 1,558 ms (16.1×) | 2,919 ms (30.2×) | — | — |
| `strlen` | String / REGEX | **105 ms** | 7,099 ms (67.7×) | — | 1,629 ms (15.5×) | 5,655 ms (53.9×) | — | — |
| `strstarts` | String / REGEX | **42 ms** | 6,700 ms (160.2×) | — | 1,553 ms (37.1×) | 2,925 ms (69.9×) | — | — |
| `transitive-path-large-join-and-plus` | Transitive paths | **1 ms** | 682 ms (1142.4×) | — | 137 ms (229.1×) | 2,897 ms (4852.8×) | — | — |
| `transitive-path-plus` | Transitive paths | **1 ms** | 1 ms (1.6×) | 252 ms (503.2×) | — | 1 ms (1.4×) | — | — |
| `transitive-path-plus-fixed-subject` | Transitive paths | **1 ms** | 1 ms (1.2×) | 902 ms (1374.9×) | 1 ms (1.5×) | 1 ms (1.1×) | — | — |
| `transitive-path-small-join-and-plus` | Transitive paths | 1 ms (1.3×) | 1 ms (2.0×) | 248 ms (515.5×) | 1 ms (1.8×) | **0 ms** | 5 ms (9.5×) | — |
| `result-size-large` | Result size / export | 711 ms (2.3×) | **310 ms** | 180,001 ms (580.1×) | 17,068 ms (55.0×) | 345 ms (1.1×) | 155,530 ms (501.2×) | — |
| `result-size-medium` | Result size / export | 61 ms (1.8×) | 37 ms (1.1×) | 48,436 ms (1392.8×) | 1,555 ms (44.7×) | **35 ms** | 6,033 ms (173.5×) | — |
| `result-size-small` | Result size / export | 4 ms (5.2×) | 2 ms (2.9×) | 488 ms (638.7×) | 5 ms (6.9×) | **1 ms** | 6 ms (7.5×) | — |
| `result-size-tiny` | Result size / export | 3 ms (5.8×) | 2 ms (3.5×) | 5 ms (11.3×) | 1 ms (2.0×) | **0 ms** | 4 ms (9.0×) | — |
| `result-size-xlarge` | Result size / export | 7,044 ms (2.2×) | **3,194 ms** | 180,001 ms (56.4×) | 17,854 ms (5.6×) | 3,472 ms (1.1×) | — | — |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 512 s | 1.10 M tr/s | 20.1 GB | 27 GB | fluree init && fluree create dblp --from dblp.nt; auto parallelism 9 (capped by 37.75 GB mem budget on the 64 GB box), 768 MB chunks, 92 committed chunks. 561.5M flakes in ~512 s @ 1.10 M flakes/s, I/O-bound — across fresh boxes import has ranged 458-527 s. Fluree counts 561,544,658 distinct triples vs 574,218,804 raw N-Triples lines (~2.2% exact-duplicate dedup on import). |
| QLever | 521 s | 1.08 M tr/s | 20.8 GB | 9.4 GB | qlever index (native), parallel parse @ 2.3 M/s. in-memory-compressed vocab, num-triples-per-batch 1M (matches the paper). Native on the host needed two things Docker masked: ulimit -n raised to 1048576 (533 partial vocabs) and --stxxl-memory 20G (permutation merge). QLever counts 561,477,456 distinct triples (Fluree 561,544,658; +0.012% delta, different exact-dup handling). |
| Oxigraph | 572 s | 0.98 M tr/s | n/a | 43 GB | oxigraph load --format nt --lenient. Till-ready = 329 s parse @ 1.70 M t/s + ~243 s RocksDB compaction (engine not queryable until compaction settles). Loaded 561,477,456 triples. No COUNT fastpath: a full COUNT(?s) takes ~224 s. 39/105 queries completed within 180 s; 66/105 timed out. |
| Virtuoso | ~700 s | ~0.8 M tr/s | ~28 GB | 17 GB | Ubuntu apt virtuoso-opensource-7 (07.20.3229). apt version has a broken ld_dir; data loaded via chunked TTLP(file_to_string(chunk)) in parallel (split -l 50000 + 8 threads). Loaded 561,483,067 triples, 90 predicates. number-of-objects timed out (>180 s full distinct scan); transitive-path-plus returned engine error. 103/105 completed. |
| MillenniumDB | 1241 s | 0.45 M tr/s | ~40 GB | 21 GB | mdb import --format ttl --buffer-strings 20GB --buffer-tensors 20GB (scaled down from the paper's 40GB+40GB=80GB, which OOMs a 64GB box). Loaded 561,477,456 triples, 90 predicates. number-of-objects/number-of-subjects timed out (>180 s full distinct scans); 103/105 completed. |
| Jena | 7471 s | 0.075 M tr/s | ~33 GB | 54 GB | tdb2.xloader (external-sort bulk loader) — by far the slowest here. Loaded from the 574.2M-line .nt. TDB index was pre-built; Fuseki started cold for the benchmark run (no JVM warmup). Cold 54GB index reads and no COUNT fastpath caused 71/105 timeouts; only 34/105 completed. |
| Blazegraph | 9950 s | 0.056 M tr/s | n/a | 43 GB | REQUIRED skolemization: default load silently drops ALL blank-node triples (239M/561M). Skolemizing _:label -> IRI then DataLoader loaded the full dataset (COUNT(*) verified = 561,477,456 distinct triples, matching QLever/Oxigraph/MillenniumDB). +~33 min skolemize (sed) before the 9950 s load. |

- **Fluree phases:** parse + sorted-commit ~340 s (~25-30% CPU), then index build (upload_dicts + permutations) ~165 s

- **QLever phases:** parse 247 s @ 2.3 M/s + vocab merge + convert + sort/permutations; total 521 s

- **Oxigraph phases:** parse 329 s @ 1.70 M t/s + RocksDB compaction ~243 s = 572 s till-ready

- **Virtuoso phases:** chunked TTLP load (split-l-50000 + 8 threads) + checkpoint = ~700 s till-ready

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
  - All engines NATIVE (no Docker). Timeout 180 s per query. QLever result cache disabled + cleared before each run so it re-executes. Oxigraph runs single-shot, memory-capped, per-query restart-on-failure.

| engine | version | config |
|---|---|---|
| Fluree | v4.0.6 | Built from source: cargo build --release -p fluree-db-cli. Server cache auto (~31.5 GB); inline-indexed ledger. v4.0.6 adds metadata-driven fast paths and algebraic aggregate identities. |
| QLever | git 621cf31 (native) | native; MEMORY_FOR_QUERIES 26G, CACHE_MAX_SIZE 6G (disabled for benchmark), in-memory-compressed vocab, TIMEOUT 300s — matches ad-freiburg/sparqloscope docs/Qleverfile.dblp |
| Oxigraph | 0.5.8 (native, prebuilt binary) | serve-read-only; systemd MemoryMax 52G; no result cache; no server-side query timeout (issue #1336). Sweep methodology DEVIATES: warmup 0 + 1 timed run, 180 s, memory-capped with per-query restart-on-failure. RocksDB-backed. |
| Virtuoso | 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7) | 32 GB profile: NumberOfBuffers 2,720,000 (~21 GB), MaxDirtyBuffers 2,000,000, MaxQueryExecutionTime 300 s, ResultSetMaxRows 10M. Data in named graph <https://dblp.org>; queries sent with default-graph-uri. |
| MillenniumDB | v1.0.0 (built from source) | native; versioned-buffer 22GB, strings-static 4GB, strings-dynamic 4GB; body POST; no result cache. |
| Jena | Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21) | TDB2 + Fuseki; JVM_ARGS -Xmx32g; body POST; no result cache. Fuseki started cold for benchmark run. |
| Blazegraph | 2.1.6-RC (Java 11) | native jar; offline DataLoader on a SKOLEMIZED .nt (blank nodes rewritten to IRIs — required); served with -Xmx32g; web.xml queryTimeout 180000; queries via --post-form. |

**Caveats**
- All engines run NATIVE (no Docker), matching the SPARQLoscope paper's recommendation. All 7 engines ran on dedicated m7a.4xlarge boxes with fractional ms timing precision (run dblp-core-20260610-204013, 2026-06-11).
- Fluree is v4.0.6, which includes metadata-driven fast paths (number-of-literals: 0.58 ms, number-of-subjects: 1.28 ms, number-of-objects: 1.40 ms, COUNT DISTINCT, MIN/MAX string) and algebraic aggregate identities (SUM(STRLEN(GROUP_CONCAT)) without materializing the concatenation).
- Virtuoso was loaded via chunked TTLP because ld_dir is broken in Ubuntu apt 07.20.3229. We also tried rdf_loader_run in an earlier setup pass; chunked TTLP gave clearly better query times (loading method affects B-tree organization), so this run uses it. Earlier passes ran on a coarser-precision harness, so no like-for-like timing comparison is published.
- Jena: only 34/105 queries completed. Fuseki was started cold for the benchmark; a cold 54GB index on a 64GB box (32GB JVM heap) causes many heavy JOIN/OPTIONAL/EXISTS queries to time out. In an earlier setup pass with a warm OS page cache Jena completed substantially more queries (69/105), so treat the completion count as cache-state sensitive.
- NOT bit-comparable to the published SPARQLoscope table: that used DBLP 2024-04-01 / 2025-04-01 (~390-502M); this is the 2026-06-01 core archive (574.2M raw lines, ~561.5M distinct).
- Triple-count delta: Fluree 561,544,658 vs QLever 561,477,456 distinct (+0.012%) — different exact-duplicate handling on import; both agree on 90 predicates.
- Oxigraph: 39/105 queries completed within its 180 s timeout (66 timed out). Its sweep used a documented deviation (1 run, 180 s, memory-capped, per-query restart) because Oxigraph cannot cancel queries and an uncapped run OOM-locks the box; median-of-3 was infeasible. Oxigraph times are not directly comparable to the warmup+median-of-3 engines.
- Absolute times are this-box-only (m7a.4xlarge, 16c/64GB).
- Scope: this run compares query completion and latency, not result-set equivalence (correctness diffing across engines is out of scope here).
