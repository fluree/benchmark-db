# SPARQLoscope benchmark — DBLP-core (bibliography only)

> **Run 2026-06-02 · Fluree v4.0.5 official release. Standard DBLP-core (bibliography only, no OpenCitations), stable DROPS archive 2026-06-01 (574.2M raw N-Triples lines; ~561.5M distinct triples after dedup). All seven engines run NATIVE (no Docker); QLever config matches ad-freiburg/sparqloscope docs/Qleverfile.dblp. Engine-vs-engine on one box; NOT bit-comparable to the paper's 2024/2025 dumps.**

**Dataset:** 574,218,804 triples, 90 predicates (2026-06-01 (stable DROPS monthly archive)) · **Engines:** Fluree 4.0.5 (official release), QLever git 621cf31 (native), Oxigraph 0.5.8 (native, prebuilt binary), Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0 (built from source), Jena Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21), Blazegraph 2.1.6-RC (Java 11) · **Box:** AWS m7a.4xlarge (16c / 64 GB) · 1+3 runs, median, 180 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|
| passed | 105/105 | 105/105 | 36/105 | 102/105 | 103/105 | 69/105 | 3/105 |
| arith mean | **981 ms (1.0×)** | 1,986 ms (2.0×) | 22.6 s (23.0×) | 7,445 ms (7.6×) | 12.2 s (12.5×) | 51.4 s (52.4×) | 20.5 s (20.9×) |
| geo mean | **124 ms (1.0×)** | 199 ms (1.6×) | 6,042 ms (48.6×) | 611 ms (4.9×) | 1,565 ms (12.6×) | 5,649 ms (45.4×) | 20.5 s (164.9×) |
| median | **69 ms (1.0×)** | 331 ms (4.8×) | 4,964 ms (71.9×) | 1,236 ms (17.9×) | 4,070 ms (59.0×) | 14.0 s (202.6×) | 20.5 s (297.5×) |

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|
| 1.16× | 4.38× | 225.18× | 10.30× | 31.39× | 199.87× | 527.87× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph | fastest |
|---|--:|---|---|---|---|---|---|---|---|
| Dataset statistics | 6 | 61 ms (3.7×) | **16 ms (1.0×)** | — | 5,256 ms (322.1×) | 15.6 s (953.3×) | — | — | QLever |
| JOIN | 12 | **62 ms (1.0×)** | 114 ms (1.8×) | 391 ms (6.3×) | 131 ms (2.1×) | 131 ms (2.1×) | 881 ms (14.2×) | — | Fluree |
| OPTIONAL | 10 | **113 ms (1.0×)** | 510 ms (4.5×) | — | 599 ms (5.3×) | 7,521 ms (66.5×) | 3,538 ms (31.3×) | — | Fluree |
| MINUS | 10 | **133 ms (1.0×)** | 496 ms (3.7×) | 26.5 s (199.3×) | 551 ms (4.1×) | 5,807 ms (43.6×) | 85.5 s (641.9×) | — | Fluree |
| EXISTS | 10 | **126 ms (1.0×)** | 701 ms (5.6×) | 78.1 s (619.4×) | 614 ms (4.9×) | 5,868 ms (46.5×) | 7,240 ms (57.4×) | — | Fluree |
| UNION | 5 | **141 ms (1.0×)** | 495 ms (3.5×) | 83.2 s (589.3×) | 1,500 ms (10.6×) | 7,269 ms (51.5×) | 24.9 s (176.1×) | — | Fluree |
| GROUP BY / aggregate | 16 | **131 ms (1.0×)** | 243 ms (1.9×) | 16.3 s (124.3×) | 1,844 ms (14.1×) | 2,531 ms (19.3×) | 12.1 s (92.2×) | — | Fluree |
| FILTER | 3 | 98 ms (1.1×) | **90 ms (1.0×)** | — | 2,950 ms (32.6×) | 2,384 ms (26.4×) | 25.5 s (281.9×) | — | QLever |
| Numeric functions | 10 | **47 ms (1.0×)** | 81 ms (1.7×) | 4,891 ms (104.4×) | 100 ms (2.1×) | 278 ms (5.9×) | 6,290 ms (134.2×) | — | Fluree |
| Date functions | 3 | **39 ms (1.0×)** | 220 ms (5.7×) | 5,338 ms (137.5×) | 432 ms (11.1×) | 218 ms (5.6×) | 4,043 ms (104.1×) | 20.5 s (527.9×) | Fluree |
| String / REGEX | 11 | 1,675 ms (1.9×) | **873 ms (1.0×)** | — | 3,861 ms (4.4×) | 11.7 s (13.4×) | 164.3 s (188.2×) | — | QLever |
| Transitive paths | 4 | 26 ms | **5 ms** | 382 ms | 7 ms | 18 ms | 25 ms | — | QLever |
| Result size / export | 5 | 219 ms (6.6×) | 44 ms (1.3×) | 496 ms (14.9×) | 292 ms (8.8×) | **33 ms (1.0×)** | 300 ms (9.0×) | — | MillenniumDB |

### 1c. Per query

| query | category | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **64 ms (1.0×)** | 5,150 ms (80.5×) | — | 3,694 ms (57.7×) | 14.4 s (224.7×) | — | — |
| `number-of-literals` | Dataset statistics | **119 ms (1.0×)** | 3,661 ms (30.8×) | — | 3,871 ms (32.5×) | 13.7 s (115.0×) | — | — |
| `number-of-objects` | Dataset statistics | 119 ms | **0 ms** | — | — | — | — | — |
| `number-of-predicates` | Dataset statistics | 22 ms | **0 ms** | — | 33.8 s | 22.3 s | — | — |
| `number-of-subjects` | Dataset statistics | 115 ms | **0 ms** | — | — | — | — | — |
| `number-of-triples` | Dataset statistics | 22 ms | **0 ms** | — | 1,578 ms | 13.3 s | — | — |
| `join-2-large-large` | JOIN | **25 ms (1.0×)** | 357 ms (14.3×) | — | 1,876 ms (75.0×) | 6,923 ms (276.9×) | 72.5 s (2898.4×) | — |
| `join-2-large-large-with-large-result` | JOIN | **51 ms (1.0×)** | 414 ms (8.1×) | — | 2,144 ms (42.0×) | 9,088 ms (178.2×) | 88.4 s (1732.6×) | — |
| `join-2-large-large-with-small-result` | JOIN | 85 ms | 20 ms | — | 78 ms | **4 ms** | 12.0 s | — |
| `join-2-large-small` | JOIN | 26 ms | 4 ms | — | 2 ms | **1 ms** | 6 ms | — |
| `join-2-largest-result` | JOIN | **51 ms (1.0×)** | 416 ms (8.2×) | — | 2,122 ms (41.6×) | 9,093 ms (178.3×) | 86.9 s (1703.4×) | — |
| `join-2-small-large` | JOIN | 26 ms | 4 ms | — | 2 ms | **1 ms** | 6 ms | — |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | **255 ms (1.0×)** | 2,584 ms (10.1×) | — | 13.0 s (51.1×) | 27.8 s (109.0×) | — | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **184 ms (1.0×)** | 2,393 ms (13.0×) | — | 1,141 ms (6.2×) | 24.8 s (134.7×) | 118.4 s (643.5×) | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | 25 ms | 457 ms | — | 6 ms | **0 ms** | 6 ms | — |
| `join-xlarge-star-on-small-predicates` | JOIN | 27 ms | 18 ms | — | 84 ms | **0 ms** | 7 ms | — |
| `multicolumn-join-large` | JOIN | **1,141 ms (1.0×)** | 4,907 ms (4.3×) | — | 1,341 ms (1.2×) | 16.5 s (14.4×) | 69.1 s (60.6×) | — |
| `multicolumn-join-small` | JOIN | 25 ms | **0 ms** | 391 ms | **0 ms** | **0 ms** | 3 ms | — |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **52 ms (1.0×)** | 1,234 ms (23.7×) | — | 2,232 ms (42.9×) | 12.5 s (239.5×) | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | 93 ms (1.5×) | 76 ms (1.2×) | — | **62 ms (1.0×)** | 2,355 ms (38.0×) | 69.1 s (1114.4×) | — |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | 83 ms (2.1×) | **39 ms (1.0×)** | — | 89 ms (2.3×) | 3,798 ms (97.4×) | 71.2 s (1826.4×) | — |
| `optional-join-3-chain-1` | OPTIONAL | **254 ms (1.0×)** | 2,318 ms (9.1×) | — | 5,503 ms (21.7×) | 27.9 s (109.9×) | — | — |
| `optional-join-3-chain-2` | OPTIONAL | **844 ms (1.0×)** | 8,103 ms (9.6×) | — | 6,989 ms (8.3×) | 65.2 s (77.3×) | — | — |
| `optional-join-3-star-1` | OPTIONAL | **176 ms (1.0×)** | 3,485 ms (19.8×) | — | 1,615 ms (9.2×) | 37.6 s (213.8×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **197 ms (1.0×)** | 1,820 ms (9.2×) | — | 1,673 ms (8.5×) | 20.5 s (104.1×) | — | — |
| `optional-join-large-large` | OPTIONAL | **170 ms (1.0×)** | 1,467 ms (8.6×) | — | 1,863 ms (11.0×) | 43.6 s (256.7×) | — | — |
| `optional-join-large-small` | OPTIONAL | **26 ms (1.0×)** | 462 ms (17.8×) | — | 1,247 ms (48.0×) | 42.4 s (1631.2×) | — | — |
| `optional-join-small-large` | OPTIONAL | 26 ms | 4 ms | — | **2 ms** | **2 ms** | 9 ms | — |
| `minus-join-2-large-large-with-large-result` | MINUS | **48 ms (1.0×)** | 399 ms (8.3×) | 112.8 s (2349.8×) | 2,151 ms (44.8×) | 8,759 ms (182.5×) | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | 54 ms (1.1×) | **47 ms (1.0×)** | 8,912 ms (189.6×) | 62 ms (1.3×) | 2,306 ms (49.1×) | 103.0 s (2191.8×) | — |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **52 ms (1.0×)** | 54 ms (1.0×) | 6,869 ms (132.1×) | 89 ms (1.7×) | 3,766 ms (72.4×) | 103.7 s (1994.4×) | — |
| `minus-join-3-chain-1` | MINUS | **242 ms (1.0×)** | 1,414 ms (5.8×) | — | 5,202 ms (21.5×) | 20.4 s (84.2×) | 58.4 s (241.5×) | — |
| `minus-join-3-chain-2` | MINUS | **2,385 ms (1.0×)** | 8,614 ms (3.6×) | — | 5,677 ms (2.4×) | 25.2 s (10.6×) | — | — |
| `minus-join-3-star-1` | MINUS | 1,706 ms (1.1×) | 1,766 ms (1.2×) | — | **1,525 ms (1.0×)** | 36.0 s (23.6×) | — | — |
| `minus-join-3-star-2` | MINUS | **145 ms (1.0×)** | 2,041 ms (14.1×) | — | 1,141 ms (7.9×) | 18.5 s (127.7×) | — | — |
| `minus-join-large-large` | MINUS | **140 ms (1.0×)** | 778 ms (5.6×) | — | 1,740 ms (12.4×) | 40.9 s (292.3×) | — | — |
| `minus-join-large-small` | MINUS | **25 ms (1.0×)** | 601 ms (24.0×) | 71.8 s (2871.5×) | 1,225 ms (49.0×) | 41.0 s (1639.3×) | — | — |
| `minus-join-small-large` | MINUS | 26 ms | 43 ms | — | 2 ms | **1 ms** | — | — |
| `exists-join-2-large-large-with-large-result` | EXISTS | **47 ms (1.0×)** | 761 ms (16.2×) | — | 2,198 ms (46.8×) | 9,035 ms (192.2×) | 75.9 s (1614.2×) | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | **50 ms (1.0×)** | 62 ms (1.2×) | — | 60 ms (1.2×) | 2,284 ms (45.7×) | 13.8 s (276.2×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **50 ms (1.0×)** | 61 ms (1.2×) | — | 85 ms (1.7×) | 3,716 ms (74.3×) | 14.0 s (279.6×) | — |
| `exists-join-3-chain-1` | EXISTS | **250 ms (1.0×)** | 3,108 ms (12.4×) | — | 9,760 ms (39.0×) | 21.4 s (85.6×) | 169.7 s (678.9×) | — |
| `exists-join-3-chain-2` | EXISTS | **2,394 ms (1.0×)** | 10.8 s (4.5×) | — | 120.1 s (50.2×) | 25.8 s (10.8×) | — | — |
| `exists-join-3-star-1` | EXISTS | **1,651 ms (1.0×)** | 2,587 ms (1.6×) | — | 39.6 s (24.0×) | 37.1 s (22.5×) | — | — |
| `exists-join-3-star-2` | EXISTS | **101 ms (1.0×)** | 2,138 ms (21.2×) | — | 1,179 ms (11.7×) | 19.0 s (188.6×) | — | — |
| `exists-join-large-large` | EXISTS | **144 ms (1.0×)** | 896 ms (6.2×) | — | 3,082 ms (21.4×) | 40.3 s (280.2×) | — | — |
| `exists-join-large-small` | EXISTS | 25 ms | 472 ms | — | **2 ms** | 40.0 s | — | — |
| `exists-join-small-large` | EXISTS | 24 ms | 126 ms | 78.1 s | 2 ms | **1 ms** | 8 ms | — |
| `union-constraint-filter-restrictive` | UNION | 1,305 ms (1.3×) | **978 ms (1.0×)** | — | 3,272 ms (3.3×) | 4,070 ms (4.2×) | 12.9 s (13.2×) | — |
| `union-constraint-from-star` | UNION | **146 ms (1.0×)** | 1,364 ms (9.3×) | — | 2,635 ms (18.0×) | 31.3 s (214.7×) | — | — |
| `union-constraint-large-join` | UNION | **231 ms (1.0×)** | 774 ms (3.4×) | — | 4,481 ms (19.4×) | 16.4 s (70.8×) | — | — |
| `union-constraint-small-join` | UNION | **49 ms (1.0×)** | 122 ms (2.5×) | — | 250 ms (5.1×) | 2,277 ms (46.5×) | 41.9 s (854.6×) | — |
| `union-no-constraint` | UNION | **26 ms (1.0×)** | 236 ms (9.1×) | 83.2 s (3199.7×) | 786 ms (30.2×) | 4,271 ms (164.3×) | 28.5 s (1094.9×) | — |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **731 ms (1.0×)** | 2,412 ms (3.3×) | 87.5 s (119.7×) | 11.9 s (16.2×) | 4,262 ms (5.8×) | 30.8 s (42.2×) | — |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **394 ms (1.0×)** | 12.4 s (31.5×) | 39.7 s (100.8×) | 39.5 s (100.2×) | 73.0 s (185.3×) | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 1,101 ms (1.1×) | **1,022 ms (1.0×)** | — | 3,764 ms (3.7×) | 6,744 ms (6.6×) | 31.2 s (30.6×) | — |
| `group-by-complex-aggregate` | GROUP BY / aggregate | **407 ms (1.0×)** | 1,610 ms (4.0×) | — | 55.7 s (136.8×) | 18.6 s (45.7×) | — | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | 40 ms (4.0×) | **10 ms (1.0×)** | 86.2 s (8619.5×) | 544 ms (54.4×) | 3,854 ms (385.4×) | — | — |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **177 ms (1.0×)** | 1,947 ms (11.0×) | 83.6 s (472.0×) | 58.1 s (328.3×) | 27.7 s (156.3×) | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | **394 ms (1.0×)** | 684 ms (1.7×) | — | 622 ms (1.6×) | 6,526 ms (16.6×) | — | — |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | **84 ms (1.0×)** | 85 ms (1.0×) | 6,409 ms (76.3×) | 793 ms (9.4×) | 254 ms (3.0×) | 3,088 ms (36.8×) | — |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | 26 ms | **1 ms** | 4,459 ms | 30 ms | 229 ms | 2,935 ms | — |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **26 ms (1.0×)** | 78 ms (3.0×) | 4,630 ms (178.1×) | 139 ms (5.3×) | 245 ms (9.4×) | 2,989 ms (115.0×) | — |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **27 ms (1.0×)** | 79 ms (2.9×) | 4,639 ms (171.8×) | 143 ms (5.3×) | 264 ms (9.8×) | 3,441 ms (127.4×) | — |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | **67 ms (1.0×)** | 85 ms (1.3×) | 4,757 ms (71.0×) | 212 ms (3.2×) | 254 ms (3.8×) | 3,081 ms (46.0×) | — |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | 25 ms | **2 ms** | 17.7 s | 417 ms | 766 ms | 61.9 s | — |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **34 ms (1.0×)** | 262 ms (7.7×) | — | 1,408 ms (41.4×) | 1,593 ms (46.9×) | 62.9 s (1850.9×) | — |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **34 ms (1.0×)** | 261 ms (7.7×) | — | 1,030 ms (30.3×) | 1,551 ms (45.6×) | 61.1 s (1798.2×) | — |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **6,956 ms (1.0×)** | 37.0 s (5.3×) | — | 152.4 s (21.9×) | 57.8 s (8.3×) | — | — |
| `filter-few-results` | FILTER | **167 ms (1.0×)** | 782 ms (4.7×) | — | 644 ms (3.9×) | 3,316 ms (19.9×) | 10.4 s (62.5×) | — |
| `filter-language-en` | FILTER | 33 ms | **0 ms** | — | 56.5 s | 809 ms | 62.3 s | — |
| `filter-many-results` | FILTER | **169 ms (1.0×)** | 946 ms (5.6×) | — | 706 ms (4.2×) | 5,050 ms (29.9×) | — | — |
| `numeric-abs` | Numeric functions | **69 ms (1.0×)** | 188 ms (2.7×) | 4,901 ms (71.0×) | 185 ms (2.7×) | 297 ms (4.3×) | 3,673 ms (53.2×) | — |
| `numeric-add` | Numeric functions | **70 ms (1.0×)** | 259 ms (3.7×) | 5,021 ms (71.7×) | 108 ms (1.5×) | 321 ms (4.6×) | 4,772 ms (68.2×) | — |
| `numeric-baseline` | Numeric functions | **68 ms (1.0×)** | 84 ms (1.2×) | 4,690 ms (69.0×) | 212 ms (3.1×) | 254 ms (3.7×) | 3,583 ms (52.7×) | — |
| `numeric-ceil` | Numeric functions | **69 ms (1.0×)** | 188 ms (2.7×) | 4,853 ms (70.3×) | 201 ms (2.9×) | 295 ms (4.3×) | 3,682 ms (53.4×) | — |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **26 ms (1.0×)** | 31 ms (1.2×) | 5,014 ms (192.8×) | 108 ms (4.2×) | 307 ms (11.8×) | 92.6 s (3560.8×) | — |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | 26 ms | 5 ms | 4,813 ms | **4 ms** | 235 ms | 2,733 ms | — |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | 27 ms (1.2×) | **23 ms (1.0×)** | 5,000 ms (217.4×) | 89 ms (3.9×) | 286 ms (12.4×) | 66.6 s (2896.0×) | — |
| `numeric-floor` | Numeric functions | **69 ms (1.0×)** | 188 ms (2.7×) | 4,929 ms (71.4×) | 200 ms (2.9×) | 292 ms (4.2×) | 2,483 ms (36.0×) | — |
| `numeric-greater` | Numeric functions | **26 ms (1.0×)** | 121 ms (4.7×) | 4,779 ms (183.8×) | 77 ms (3.0×) | 219 ms (8.4×) | 4,066 ms (156.4×) | — |
| `numeric-round` | Numeric functions | **69 ms (1.0×)** | 187 ms (2.7×) | 4,924 ms (71.4×) | 200 ms (2.9×) | 297 ms (4.3×) | 2,462 ms (35.7×) | — |
| `date-day` | Date functions | **33 ms (1.0×)** | 235 ms (7.1×) | 6,330 ms (191.8×) | 562 ms (17.0×) | 218 ms (6.6×) | 4,020 ms (121.8×) | 20.4 s (618.8×) |
| `date-month` | Date functions | **25 ms (1.0×)** | 234 ms (9.4×) | 4,449 ms (178.0×) | 375 ms (15.0×) | 218 ms (8.7×) | 4,842 ms (193.7×) | 20.5 s (821.2×) |
| `date-year` | Date functions | **71 ms (1.0×)** | 194 ms (2.7×) | 5,402 ms (76.1×) | 383 ms (5.4×) | 218 ms (3.1×) | 3,394 ms (47.8×) | 20.6 s (289.5×) |
| `regex-3` | String / REGEX | 12.4 s (1.8×) | 7,353 ms (1.1×) | — | **6,941 ms (1.0×)** | 21.3 s (3.1×) | 168.8 s (24.3×) | — |
| `regex-3-contains` | String / REGEX | 7,336 ms (2.5×) | 6,821 ms (2.3×) | — | 3,345 ms (1.2×) | **2,905 ms (1.0×)** | — | — |
| `regex-3-fixed` | String / REGEX | 11.4 s (3.0×) | 7,277 ms (1.9×) | — | **3,792 ms (1.0×)** | 21.3 s (5.6×) | 166.2 s (43.8×) | — |
| `regex-prefix-1` | String / REGEX | 207 ms | **6 ms** | — | 3,645 ms | 19.7 s | 162.6 s | — |
| `regex-prefix-2` | String / REGEX | 66 ms | **3 ms** | — | 3,623 ms | 20.8 s | 162.1 s | — |
| `regex-prefix-3` | String / REGEX | 39 ms | **1 ms** | — | 3,631 ms | 21.4 s | 161.7 s | — |
| `strafter` | String / REGEX | 9,048 ms (2.3×) | 10.8 s (2.8×) | — | **3,910 ms (1.0×)** | 33.8 s (8.7×) | 168.5 s (43.1×) | — |
| `strbefore` | String / REGEX | 8,853 ms (2.4×) | 10.3 s (2.8×) | — | **3,692 ms (1.0×)** | 11.5 s (3.1×) | 166.9 s (45.2×) | — |
| `strends` | String / REGEX | 8,157 ms (3.0×) | 6,628 ms (2.4×) | — | 3,548 ms (1.3×) | **2,751 ms (1.0×)** | 162.3 s (59.0×) | — |
| `strlen` | String / REGEX | 9,471 ms (2.6×) | 6,937 ms (1.9×) | — | **3,705 ms (1.0×)** | 5,443 ms (1.5×) | 161.5 s (43.6×) | — |
| `strstarts` | String / REGEX | **85 ms (1.0×)** | 6,683 ms (78.6×) | — | 3,546 ms (41.7×) | 8,607 ms (101.3×) | 162.5 s (1912.3×) | — |
| `transitive-path-large-join-and-plus` | Transitive paths | **27 ms (1.0×)** | 685 ms (25.4×) | — | 383 ms (14.2×) | 2,897 ms (107.3×) | 24.0 s (888.1×) | — |
| `transitive-path-plus` | Transitive paths | 26 ms | **0 ms** | 374 ms | — | 3 ms | 4 ms | — |
| `transitive-path-plus-fixed-subject` | Transitive paths | 26 ms | **0 ms** | 427 ms | 1 ms | 3 ms | 1 ms | — |
| `transitive-path-small-join-and-plus` | Transitive paths | 26 ms | **0 ms** | 349 ms | 1 ms | 4 ms | 4 ms | — |
| `result-size-large` | Result size / export | 771 ms (2.3×) | **331 ms (1.0×)** | — | 16.9 s (51.1×) | 349 ms (1.1×) | 11.7 s (35.2×) | — |
| `result-size-medium` | Result size / export | 104 ms (3.1×) | 38 ms (1.1×) | 44.9 s (1320.0×) | 1,416 ms (41.6×) | **34 ms (1.0×)** | 141 ms (4.1×) | — |
| `result-size-small` | Result size / export | 29 ms | 2 ms | 454 ms | 5 ms | **0 ms** | 4 ms | — |
| `result-size-tiny` | Result size / export | 28 ms | 2 ms | 6 ms | **0 ms** | **0 ms** | 3 ms | — |
| `result-size-xlarge` | Result size / export | 7,708 ms (2.3×) | **3,374 ms (1.0×)** | — | 17.8 s (5.3×) | 3,497 ms (1.0×) | 124.2 s (36.8×) | — |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 527 s | 1.07 M tr/s | 21.4 GB | 27 GB | fluree create dblp --from dblp.ttl on the official v4.0.5 release; auto parallelism 9 (capped by 37.75 GB mem budget on the 64 GB box), 768 MB chunks, 92 committed chunks. I/O-bound, not CPU-bound: the import is disk/EBS-bound, so time is box-variance dominated — across the v4.0.5-release fresh boxes it ranged 458-527 s (the pre-release ba88283 run on the original box was 504 s @ 1.14 M tr/s / 21.9 GB peak). Fluree counts 561,544,658 distinct triples vs 574,218,804 raw N-Triples lines (~2.2% exact-duplicate dedup on import). |
| QLever | 521 s | 1.08 M tr/s | 20.8 GB | 9.4 GB | qlever index (native), parallel parse @ 2.3 M/s. in-memory-compressed vocab, num-triples-per-batch 1M (matches the paper). Native on the host needed two things Docker masked: ulimit -n raised to 1048576 (533 partial vocabs) and --stxxl-memory 20G (permutation merge). QLever counts 561,477,456 distinct triples (Fluree 561,544,658; +0.012% delta, different exact-dup handling). |
| Oxigraph | 572 s | 0.98 M tr/s | n/a | 43 GB | oxigraph load --format nt --lenient. Till-ready = 329 s parse @ 1.70 M t/s + ~243 s RocksDB compaction (engine not queryable until compaction settles). Loaded 561,477,456 triples (same distinct count as QLever). No COUNT fastpath: a full COUNT(?s) takes ~224 s. 36/105 queries completed within 180 s; 69/105 timed out. |
| Virtuoso | 628 s | 0.89 M tr/s | 27.7 GB | 17 GB | Till-ready = 217 s split (16-way) + 411 s parallel load (8 rdf_loader_run) + checkpoint. Loaded 561,483,067 triples, 90 predicates (matches the others). Single-file unsplit load would be far slower. No COUNT fastpath: number-of-objects and number-of-subjects timed out (>300 s full distinct scans); transitive-path-plus returned HTTP 500 (engine error). 102/105 completed. |
| MillenniumDB | 1241 s | 0.45 M tr/s | ~40 GB | 21 GB | mdb import --format ttl --buffer-strings 20GB --buffer-tensors 20GB (scaled down from the paper's 40GB+40GB=80GB, which OOMs a 64GB box). Loaded 561,477,456 triples, 90 predicates. number-of-objects/number-of-subjects timed out (>180 s full distinct scans); 103/105 completed. |
| Jena | 7471 s | 0.075 M tr/s | ~33 GB | 54 GB | tdb2.xloader (external-sort bulk loader) — by far the slowest here: nodes ~20 min, then terms, data, and a separate build of each permutation (SPO/POS/OSP). Loaded from the 574.2M-line .ttl. No COUNT fastpath + cold 54GB index reads make queries slow: 36/105 timed out (all dataset-statistics counts, heavy joins/exists/minus/optional, big group-bys). |
| Blazegraph | 9950 s | 0.056 M tr/s | n/a | 43 GB | REQUIRED skolemization: chunked LOAD and default/storeBlankNodes DataLoader all loaded only 239,412,597 of ~561.5M (every blank-node triple dropped). Skolemizing _:label -> IRI then DataLoader gave the full 561,544,658 (verified COUNT(*) = 561,477,456 distinct, hasSignature present). +~33 min skolemize (sed) before the 9950 s load. Chunked LOAD also GC-thrashed/decelerated (~4.5h) — abandoned. |

- **Fluree phases:** parse + sorted-commit ~340 s (~25-30% CPU), then index build (upload_dicts + permutations) ~165 s

- **QLever phases:** parse 247 s @ 2.3 M/s + vocab merge + convert + sort/permutations; total 521 s

- **Oxigraph phases:** parse 329 s @ 1.70 M t/s + RocksDB compaction ~243 s = 572 s till-ready

- **Virtuoso phases:** split 217 s + 8 parallel loaders 411 s + checkpoint = 628 s till-ready

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
| Fluree | 4.0.5 (official release) (`v4.0.5 (GitHub release, installed via fluree-db-cli-installer.sh; §1 figures are the release binary on a fresh m7a.4xlarge. The pre-release branch feature/count-plan-aggregate-fastpaths @ ba88283 on the original box gave matching numbers, 936 ms / 67 ms.)`) | server cache auto (~31.5 GB); inline-indexed ledger. Native binary installed via the GitHub releases shell installer (fluree-db-cli-installer.sh); benchmarked natively, not the Docker image. |
| QLever | git 621cf31 (native) (`621cf31 (native binaries from adfreiburg/qlever:latest image, run directly — no Docker)`) | native; MEMORY_FOR_QUERIES 26G, CACHE_MAX_SIZE 6G (disabled for the benchmark), in-memory-compressed vocab, TIMEOUT 300s — matches ad-freiburg/sparqloscope docs/Qleverfile.dblp |
| Oxigraph | 0.5.8 (native, prebuilt binary) (`oxigraph_v0.5.8_x86_64_linux_gnu (GitHub release)`) | serve-read-only; systemd MemoryMax 52G; no result cache; no server-side query timeout (issue #1336). Sweep methodology DEVIATES from the other engines: warmup 0 + 1 timed run, 180 s timeout, memory-capped with per-query restart-on-failure (mirrors ad-freiburg/sparqloscope util/oxigraph-helper.sh). RocksDB-backed. |
| Virtuoso | 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7) (`07.20.3229`) | 32 GB profile: NumberOfBuffers 2,720,000 (~21 GB), MaxDirtyBuffers 2,000,000, MaxQueryExecutionTime 300 s, ResultSetMaxRows 10M. Data in named graph <https://dblp.org>; benchmark queries sent form-encoded with default-graph-uri=<https://dblp.org> so they hit only dblp (the no-FROM default would union Virtuoso's system graphs). No result cache to clear (warm buffers, like Fluree). |
| MillenniumDB | v1.0.0 (built from source) (`github.com/MillenniumDB/MillenniumDB main`) | native; mdb server -t 180 --strings-static 16GB --strings-dynamic 8GB --tensors-static 8GB --tensors-dynamic 4GB; body POST; no result cache. Built on its own m7a.4xlarge (16c/64GB), dblp-core pulled from S3. |
| Jena | Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21) (`6.1.0`) | TDB2 + Fuseki; fuseki-server -Xmx32g --timeout=300000 (runner enforces 180 s); body POST; no result cache. Built on the core m7a.4xlarge (16c/64GB). |
| Blazegraph | 2.1.6-RC (Java 11) (`BLAZEGRAPH_2_1_6_RC`) | native jar; offline DataLoader on a SKOLEMIZED .nt (blank nodes rewritten to IRIs — required: default load silently drops ALL blank-node triples, 239M/561M); served with -Xmx16g so the OS page cache can hold the journal; web.xml queryTimeout 180000; queries via --post-form. Dedicated m7a.4xlarge. |

**Caveats**
- Both engines run NATIVE (no Docker), matching the SPARQLoscope paper's recommendation (containerization overhead distorts results). QLever uses the upstream binaries (git 621cf31) extracted from adfreiburg/qlever:latest and run directly; Fluree is the official v4.0.5 release (native binary from the GitHub releases shell installer; §1 numbers were measured on its pre-release branch ba88283 and re-validated on the release binary).
- Fluree numbers are from the official v4.0.5 release on a fresh m7a.4xlarge (105/105, arith 981 ms, median 69 ms, geo 124 ms); the other six engines were measured on the original box. Same spec, different physical instance — the gap is well inside box-CPU variance and does not change rankings (Fluree leads every aggregate). Confirmed by a second fresh release box (957 ms / 71 ms) and the pre-release ba88283 run on the original box (936 ms / 67 ms). Query arith mean is box-CPU-variance dominated at the heavy string/regex tail (a third fresh draw hit 1,046 ms with identical median/geo); median and geo are stable across all draws.
- NOT bit-comparable to the published SPARQLoscope table: that used DBLP 2024-04-01 / 2025-04-01 (~390-502M); this is the 2026-06-01 core archive (574.2M raw lines, ~561.5M distinct). Engine-vs-engine on this box is valid; absolute per-query COUNTS will not match the paper's reference yaml.
- Triple-count delta: Fluree 561,544,658 vs QLever 561,477,456 distinct (+0.012%) — different exact-duplicate handling on import; both agree on 90 predicates.
- QLever result cache disabled + cleared per query (re-executes each run) to match Fluree's no-result-cache behavior; this is stricter than the paper's run-once-with-warm-cache protocol.
- Absolute times are this-box-only (m7a.4xlarge, 16c/64GB).
- Oxigraph completed only 36/105 queries within its 180 s timeout (69 timed out) on this 561.5M-triple dataset, and has no COUNT fastpath. Its sweep used a documented deviation (1 run, 180 s, memory-capped, per-query restart) because Oxigraph cannot cancel queries and an uncapped run OOM-locked the box; median-of-3 was infeasible. Oxigraph times are not directly comparable to the warmup+median-of-3 engines and are best read as 'completed vs timed out'.
- Scope: this run compares query completion and latency, not result-set equivalence (correctness diffing across engines is out of scope here).
