# SPARQLoscope benchmark — DBLP-core (bibliography only)

> **Fluree v4.2.6: 105/105 queries, 16.7 ms geometric mean; QLever 202.4 ms and Virtuoso 299.7 ms. Native engines on matching m7a.4xlarge hardware, using the same DBLP snapshot and 105 queries.**

**Dataset:** 561,477,456 triples, 90 predicates (2026-06-01 (stable DROPS monthly archive)) · **Engines:** Fluree v4.2.6, QLever git 621cf31 (native), Oxigraph 0.5.8 (native, prebuilt binary), Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0 (built from source), Jena Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21), Blazegraph 2.1.6-RC (Java 11) · **Box:** AWS m7a.4xlarge (16c / 64 GB) · 1+3 runs, median, 180 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|
| passed | 105/105 | 105/105 | 39/105 | 103/105 | 103/105 | 34/105 | 3/105 |
| geo mean (P=2) | **16.7 ms (1.0×)** | 202.4 ms (12.1×) | 87.0 s (5223.4×) | 299.7 ms (18.0×) | 1,664.2 ms (99.9×) | 67.7 s (4060.2×) | 332.9 s (19975.9×) |
| geo mean (P=10) | **16.7 ms (1.0×)** | 202.4 ms (12.1×) | 239.4 s (14364.9×) | 309.1 ms (18.5×) | 1,716.0 ms (103.0×) | 200.9 s (12055.4×) | 1589.5 s (95390.8×) |
| geo mean (passed only) | **16.7 ms (1.0×)** | 202.4 ms (12.1×) | 7,874.7 ms (472.6×) | 261.2 ms (15.7×) | 1,499.2 ms (90.0×) | 2,061.7 ms (123.7×) | 23.2 s (1390.4×) |
| arith mean (passed only) | **224.9 ms (1.0×)** | 1,904.3 ms (8.5×) | 36.8 s (163.4×) | 8,020.2 ms (35.7×) | 12.3 s (54.7×) | 31.0 s (137.9×) | 23.2 s (103.0×) |
| median (passed only) | **26.4 ms (1.0×)** | 310.3 ms (11.7×) | 5,089.9 ms (192.4×) | 326.0 ms (12.3×) | 3,894.5 ms (147.2×) | 4,540.7 ms (171.7×) | 23.2 s (875.4×) |

_geo mean (P=2/P=10) is the SPARQLoscope paper's official aggregate: a failed or timed-out query counts as 2× / 10× the 180 s timeout. The passed-only rows average each engine's completed queries only, so they flatter engines with many failures._

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|
| 1.16× | 8.84× | 280.31× | 5.84× | 55.32× | 281.32× | 608.23× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph | fastest |
|---|--:|---|---|---|---|---|---|---|---|
| Dataset statistics | 6 | **1.03 ms** | 13.7 ms | — | 13.3 s | 15.6 s | — | — | Fluree |
| JOIN | 12 | **7.98 ms** | 115.5 ms | 298.3 ms | 41.5 ms | 137.5 ms | 680.7 ms | — | Fluree |
| OPTIONAL | 10 | **41.1 ms (1.0×)** | 507.6 ms (12.3×) | — | 228.1 ms (5.5×) | 7,422.9 ms (180.5×) | — | — | Fluree |
| MINUS | 10 | **48.5 ms (1.0×)** | 518.9 ms (10.7×) | 38.8 s (800.9×) | 214.7 ms (4.4×) | 6,336.7 ms (130.8×) | 103.8 s (2142.0×) | — | Fluree |
| EXISTS | 10 | **47.7 ms (1.0×)** | 712.1 ms (14.9×) | 173.3 s (3635.8×) | 213.9 ms (4.5×) | 6,482.1 ms (136.0×) | 7,635.7 ms (160.2×) | — | Fluree |
| UNION | 5 | **52.3 ms (1.0×)** | 483.1 ms (9.2×) | 100.3 s (1918.2×) | 382.9 ms (7.3×) | 7,263.1 ms (138.9×) | 14.0 s (267.0×) | — | Fluree |
| GROUP BY / aggregate | 16 | **8.02 ms** | 271.8 ms | 15.4 s | 692.6 ms | 2,562.0 ms | 5,175.2 ms | — | Fluree |
| FILTER | 3 | **25.3 ms (1.0×)** | 87.2 ms (3.5×) | — | 1,309.6 ms (51.8×) | 2,407.0 ms (95.3×) | 26.4 s (1046.2×) | — | Fluree |
| Numeric functions | 10 | **8.97 ms** | 81.6 ms | 5,034.4 ms | 28.5 ms | 279.6 ms | — | — | Fluree |
| Date functions | 3 | **2.52 ms** | 220.2 ms | 4,844.3 ms | 95.3 ms | 218.3 ms | 2,039.1 ms | 23.2 s | Fluree |
| String / REGEX | 11 | **90.3 ms (1.0×)** | 957.2 ms (10.6×) | — | 1,920.6 ms (21.3×) | 10.8 s (119.2×) | — | — | Fluree |
| Transitive paths | 4 | **0.61 ms** | 4.48 ms | 383.7 ms | 4.81 ms | 5.18 ms | 4.60 ms | — | Fluree |
| Result size / export | 5 | 62.2 ms (2.3×) | 41.9 ms (1.5×) | 5,239.1 ms (193.4×) | 294.7 ms (10.9×) | **27.1 ms (1.0×)** | 386.1 ms (14.3×) | — | MillenniumDB |

### 1c. Per query

| query | category | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **1.99 ms** | 5,164.3 ms | — | 1,383.3 ms | 14.4 s | — | — |
| `number-of-literals` | Dataset statistics | **0.61 ms** | 3,484.3 ms | — | 5,915.1 ms | 13.7 s | — | — |
| `number-of-objects` | Dataset statistics | 1.54 ms | **0.84 ms** | — | — | — | — | — |
| `number-of-predicates` | Dataset statistics | **0.65 ms** | 0.70 ms | — | 57.1 s | 22.4 s | — | — |
| `number-of-subjects` | Dataset statistics | 1.45 ms | **0.82 ms** | — | 177.9 s | — | — | — |
| `number-of-triples` | Dataset statistics | **0.67 ms** | 0.77 ms | — | 5,004.1 ms | 13.4 s | — | — |
| `join-2-large-large` | JOIN | **0.58 ms** | 349.9 ms | — | 920.6 ms | 6,917.4 ms | 80.4 s | — |
| `join-2-large-large-with-large-result` | JOIN | **23.3 ms (1.0×)** | 414.1 ms (17.8×) | — | 853.4 ms (36.6×) | 9,035.7 ms (387.3×) | 93.5 s (4007.6×) | — |
| `join-2-large-large-with-small-result` | JOIN | 36.2 ms | 20.1 ms | — | 17.0 ms | **4.77 ms** | 12.9 s | — |
| `join-2-large-small` | JOIN | **0.64 ms** | 4.51 ms | — | 1.81 ms | 1.96 ms | 8.17 ms | — |
| `join-2-largest-result` | JOIN | **22.9 ms (1.0×)** | 415.0 ms (18.1×) | — | 859.2 ms (37.5×) | 9,029.0 ms (393.7×) | 94.8 s (4135.1×) | — |
| `join-2-small-large` | JOIN | **0.55 ms** | 4.59 ms | — | 1.91 ms | 2.48 ms | 7.80 ms | — |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | **226.5 ms (1.0×)** | 2,587.1 ms (11.4×) | — | 7,458.1 ms (32.9×) | 27.6 s (121.9×) | — | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **105.3 ms (1.0×)** | 2,282.0 ms (21.7×) | — | 232.6 ms (2.2×) | 24.9 s (236.1×) | — | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | 0.91 ms | 453.4 ms | — | **0.83 ms** | 0.84 ms | 10.8 ms | — |
| `join-xlarge-star-on-small-predicates` | JOIN | 0.95 ms | 18.7 ms | — | 0.90 ms | **0.75 ms** | 10.3 ms | — |
| `multicolumn-join-large` | JOIN | 1,098.2 ms (1.9×) | 4,891.1 ms (8.6×) | — | **568.8 ms (1.0×)** | 16.5 s (29.1×) | 69.8 s (122.7×) | — |
| `multicolumn-join-small` | JOIN | 0.74 ms | 0.93 ms | 298.3 ms | 0.90 ms | **0.49 ms** | 4.75 ms | — |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **24.5 ms (1.0×)** | 1,231.6 ms (50.3×) | — | 1,004.9 ms (41.0×) | 12.4 s (508.2×) | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | 39.5 ms (2.0×) | 78.8 ms (4.0×) | — | **19.6 ms (1.0×)** | 2,398.4 ms (122.2×) | — | — |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | 33.2 ms (1.1×) | 39.1 ms (1.3×) | — | **29.9 ms (1.0×)** | 3,877.2 ms (129.5×) | — | — |
| `optional-join-3-chain-1` | OPTIONAL | **227.9 ms (1.0×)** | 2,277.9 ms (10.0×) | — | 2,877.9 ms (12.6×) | 27.7 s (121.6×) | — | — |
| `optional-join-3-chain-2` | OPTIONAL | **808.2 ms (1.0×)** | 8,149.5 ms (10.1×) | — | 2,972.1 ms (3.7×) | 65.1 s (80.5×) | — | — |
| `optional-join-3-star-1` | OPTIONAL | **117.7 ms (1.0×)** | 3,016.6 ms (25.6×) | — | 326.0 ms (2.8×) | 37.6 s (319.2×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **251.5 ms (1.0×)** | 1,720.8 ms (6.8×) | — | 351.8 ms (1.4×) | 20.9 s (83.3×) | — | — |
| `optional-join-large-large` | OPTIONAL | **137.6 ms (1.0×)** | 1,466.5 ms (10.7×) | — | 690.7 ms (5.0×) | 43.9 s (319.0×) | — | — |
| `optional-join-large-small` | OPTIONAL | **0.76 ms** | 462.7 ms | — | 490.9 ms | 42.7 s | — | — |
| `optional-join-small-large` | OPTIONAL | **0.76 ms** | 4.58 ms | — | 1.94 ms | 1.65 ms | — | — |
| `minus-join-2-large-large-with-large-result` | MINUS | **20.6 ms (1.0×)** | 425.2 ms (20.6×) | 110.3 s (5342.1×) | 1,011.0 ms (49.0×) | 8,773.8 ms (425.0×) | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | 26.4 ms (1.3×) | 47.7 ms (2.4×) | 8,673.7 ms (436.7×) | **19.9 ms (1.0×)** | 2,389.1 ms (120.3×) | — | — |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **25.1 ms (1.0×)** | 61.8 ms (2.5×) | 7,020.9 ms (279.8×) | 30.1 ms (1.2×) | 3,888.2 ms (154.9×) | — | — |
| `minus-join-3-chain-1` | MINUS | **220.5 ms (1.0×)** | 1,406.7 ms (6.4×) | — | 2,880.3 ms (13.1×) | 20.5 s (92.9×) | 103.8 s (470.8×) | — |
| `minus-join-3-chain-2` | MINUS | **2,640.9 ms (1.0×)** | 8,650.5 ms (3.3×) | — | 2,914.6 ms (1.1×) | 25.5 s (9.7×) | — | — |
| `minus-join-3-star-1` | MINUS | 1,424.4 ms (4.5×) | 2,120.4 ms (6.8×) | — | **314.0 ms (1.0×)** | 36.0 s (114.7×) | — | — |
| `minus-join-3-star-2` | MINUS | **97.1 ms (1.0×)** | 2,031.3 ms (20.9×) | — | 231.6 ms (2.4×) | 19.2 s (198.0×) | — | — |
| `minus-join-large-large` | MINUS | **116.7 ms (1.0×)** | 810.7 ms (6.9×) | 177.1 s (1517.7×) | 618.5 ms (5.3×) | 41.5 s (355.5×) | — | — |
| `minus-join-large-small` | MINUS | **0.78 ms** | 611.0 ms | 74.1 s | 464.1 ms | 41.3 s | — | — |
| `minus-join-small-large` | MINUS | **0.71 ms** | 43.5 ms | — | 1.96 ms | 2.06 ms | — | — |
| `exists-join-2-large-large-with-large-result` | EXISTS | **21.0 ms (1.0×)** | 788.6 ms (37.5×) | — | 957.2 ms (45.5×) | 9,070.8 ms (431.1×) | 79.0 s (3754.3×) | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | 26.0 ms (1.4×) | 59.6 ms (3.3×) | — | **18.1 ms (1.0×)** | 2,378.4 ms (131.5×) | 13.9 s (768.3×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **25.1 ms (1.0×)** | 59.9 ms (2.4×) | — | 31.4 ms (1.2×) | 3,894.5 ms (155.0×) | 14.0 s (559.1×) | — |
| `exists-join-3-chain-1` | EXISTS | **224.1 ms (1.0×)** | 3,693.2 ms (16.5×) | — | 12.0 s (53.5×) | 21.4 s (95.4×) | 170.0 s (758.8×) | — |
| `exists-join-3-chain-2` | EXISTS | **2,653.8 ms (1.0×)** | 10.2 s (3.8×) | — | 171.6 s (64.7×) | 25.9 s (9.8×) | — | — |
| `exists-join-3-star-1` | EXISTS | 1,440.9 ms (4.1×) | 2,607.1 ms (7.4×) | — | **352.1 ms (1.0×)** | 37.3 s (106.0×) | — | — |
| `exists-join-3-star-2` | EXISTS | **99.2 ms (1.0×)** | 2,412.3 ms (24.3×) | — | 240.0 ms (2.4×) | 19.8 s (199.4×) | — | — |
| `exists-join-large-large` | EXISTS | **116.3 ms (1.0×)** | 851.3 ms (7.3×) | — | 629.4 ms (5.4×) | 40.8 s (350.7×) | — | — |
| `exists-join-large-small` | EXISTS | **0.65 ms** | 469.8 ms | — | 1.89 ms | 40.5 s | — | — |
| `exists-join-small-large` | EXISTS | **0.68 ms** | 126.1 ms | 173.3 s | 1.79 ms | 2.31 ms | 9.90 ms | — |
| `union-constraint-filter-restrictive` | UNION | 1,300.0 ms (2.2×) | 944.1 ms (1.6×) | — | **581.6 ms (1.0×)** | 4,106.1 ms (7.1×) | 14.0 s (24.0×) | — |
| `union-constraint-from-star` | UNION | **115.3 ms (1.0×)** | 1,323.6 ms (11.5×) | — | 374.9 ms (3.3×) | 31.4 s (272.0×) | — | — |
| `union-constraint-large-join` | UNION | **186.6 ms (1.0×)** | 764.2 ms (4.1×) | — | 1,803.9 ms (9.7×) | 16.4 s (88.0×) | — | — |
| `union-constraint-small-join` | UNION | **16.4 ms (1.0×)** | 117.3 ms (7.1×) | — | 35.6 ms (2.2×) | 2,239.8 ms (136.2×) | — | — |
| `union-no-constraint` | UNION | **0.85 ms** | 234.7 ms | 100.3 s | 586.8 ms | 4,270.5 ms | — | — |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **0.87 ms** | 2,478.2 ms | 69.1 s | 11.3 s | 4,274.4 ms | 21.9 s | — |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **0.63 ms** | 12.9 s | 31.8 s | 36.1 s | 78.6 s | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | **1,041.0 ms (1.0×)** | 1,044.0 ms (1.0×) | — | 2,902.4 ms (2.8×) | 6,752.3 ms (6.5×) | 30.1 s (28.9×) | — |
| `group-by-complex-aggregate` | GROUP BY / aggregate | **376.0 ms (1.0×)** | 1,962.3 ms (5.2×) | — | 39.3 s (104.6×) | 18.7 s (49.7×) | — | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | **3.58 ms** | 10.5 ms | 81.1 s | 185.5 ms | 3,858.2 ms | — | — |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **154.9 ms (1.0×)** | 1,927.6 ms (12.4×) | 81.6 s (527.2×) | 6,776.0 ms (43.8×) | 28.0 s (181.0×) | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | 362.8 ms (5.4×) | 1,513.6 ms (22.4×) | — | **67.5 ms (1.0×)** | 6,528.8 ms (96.8×) | — | — |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | **36.4 ms (1.0×)** | 85.4 ms (2.3×) | 5,831.3 ms (160.3×) | 193.0 ms (5.3×) | 255.4 ms (7.0×) | 2,807.0 ms (77.2×) | — |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | **0.63 ms** | 2.29 ms | 4,461.0 ms | 5.96 ms | 229.5 ms | 2,646.3 ms | — |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **0.62 ms** | 79.1 ms | 4,660.8 ms | 78.5 ms | 245.9 ms | 2,506.7 ms | — |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **0.66 ms** | 79.0 ms | 4,706.0 ms | 80.1 ms | 264.4 ms | 3,048.5 ms | — |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | **38.8 ms (1.0×)** | 85.1 ms (2.2×) | 4,726.4 ms (122.0×) | 130.1 ms (3.4×) | 255.2 ms (6.6×) | 2,663.2 ms (68.7×) | — |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | **0.68 ms** | 2.29 ms | 18.9 s | 81.0 ms | 766.9 ms | — | — |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **0.76 ms** | 262.4 ms | — | 281.2 ms | 1,697.4 ms | — | — |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **0.71 ms** | 262.4 ms | — | 205.5 ms | 1,553.5 ms | — | — |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **50.7 ms (1.0×)** | 26.8 s (528.3×) | — | 161.9 s (3192.7×) | 58.6 s (1155.2×) | — | — |
| `filter-few-results` | FILTER | **145.6 ms (1.0×)** | 766.5 ms (5.3×) | — | 223.7 ms (1.5×) | 3,328.4 ms (22.9×) | 11.0 s (75.2×) | — |
| `filter-language-en` | FILTER | **0.77 ms** | 0.90 ms | — | 38.6 s | 823.0 ms | 63.7 s | — |
| `filter-many-results` | FILTER | **144.7 ms (1.0×)** | 963.4 ms (6.7×) | — | 260.3 ms (1.8×) | 5,090.9 ms (35.2×) | — | — |
| `numeric-abs` | Numeric functions | **41.0 ms (1.0×)** | 188.8 ms (4.6×) | 5,742.0 ms (139.9×) | 43.1 ms (1.0×) | 297.6 ms (7.3×) | — | — |
| `numeric-add` | Numeric functions | 41.0 ms (1.6×) | 258.7 ms (9.9×) | 5,186.1 ms (198.4×) | **26.1 ms (1.0×)** | 323.1 ms (12.4×) | — | — |
| `numeric-baseline` | Numeric functions | **38.6 ms (1.0×)** | 85.1 ms (2.2×) | 4,730.2 ms (122.5×) | 125.4 ms (3.2×) | 255.3 ms (6.6×) | — | — |
| `numeric-ceil` | Numeric functions | **40.9 ms (1.0×)** | 189.0 ms (4.6×) | 4,937.8 ms (120.6×) | 64.9 ms (1.6×) | 295.2 ms (7.2×) | — | — |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **0.91 ms** | 30.9 ms | 5,089.9 ms | 13.7 ms | 307.6 ms | — | — |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | **1.10 ms** | 5.33 ms | 4,874.0 ms | 3.40 ms | 235.8 ms | — | — |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | **0.85 ms** | 23.6 ms | 5,006.6 ms | 10.7 ms | 286.2 ms | — | — |
| `numeric-floor` | Numeric functions | **41.0 ms (1.0×)** | 188.3 ms (4.6×) | 4,977.2 ms (121.3×) | 65.1 ms (1.6×) | 297.4 ms (7.2×) | — | — |
| `numeric-greater` | Numeric functions | **0.89 ms** | 121.2 ms | 4,916.7 ms | 17.7 ms | 219.9 ms | — | — |
| `numeric-round` | Numeric functions | **40.9 ms (1.0×)** | 188.0 ms (4.6×) | 4,946.8 ms (121.0×) | 66.3 ms (1.6×) | 297.2 ms (7.3×) | — | — |
| `date-day` | Date functions | **0.72 ms** | 234.7 ms | 4,580.7 ms | 95.5 ms | 218.2 ms | 1,654.5 ms | 23.2 s |
| `date-month` | Date functions | **0.59 ms** | 234.7 ms | 4,503.5 ms | 97.1 ms | 218.3 ms | 2,476.8 ms | 23.3 s |
| `date-year` | Date functions | **37.9 ms (1.0×)** | 193.9 ms (5.1×) | 5,510.8 ms (145.6×) | 93.2 ms (2.5×) | 218.3 ms (5.8×) | 2,069.0 ms (54.7×) | 23.0 s (608.2×) |
| `regex-3` | String / REGEX | **569.0 ms (1.0×)** | 7,380.6 ms (13.0×) | — | 9,067.5 ms (15.9×) | 21.1 s (37.1×) | — | — |
| `regex-3-contains` | String / REGEX | **116.9 ms (1.0×)** | 6,897.3 ms (59.0×) | — | 1,554.1 ms (13.3×) | 2,892.7 ms (24.8×) | — | — |
| `regex-3-fixed` | String / REGEX | **472.6 ms (1.0×)** | 7,359.1 ms (15.6×) | — | 1,709.3 ms (3.6×) | 21.3 s (45.0×) | — | — |
| `regex-prefix-1` | String / REGEX | 59.1 ms | **6.72 ms** | — | 1,793.7 ms | 19.6 s | — | — |
| `regex-prefix-2` | String / REGEX | 20.5 ms | **3.96 ms** | — | 1,720.7 ms | 20.8 s | — | — |
| `regex-prefix-3` | String / REGEX | 15.0 ms | **1.76 ms** | — | 1,675.7 ms | 21.3 s | — | — |
| `strafter` | String / REGEX | **137.8 ms (1.0×)** | 10.9 s (79.3×) | — | 1,702.7 ms (12.4×) | 34.5 s (250.2×) | — | — |
| `strbefore` | String / REGEX | **123.1 ms (1.0×)** | 10.1 s (81.9×) | — | 1,568.5 ms (12.7×) | 11.9 s (96.8×) | — | — |
| `strends` | String / REGEX | **103.1 ms (1.0×)** | 6,720.6 ms (65.2×) | — | 1,557.6 ms (15.1×) | 2,919.0 ms (28.3×) | — | — |
| `strlen` | String / REGEX | **114.4 ms (1.0×)** | 7,098.8 ms (62.0×) | — | 1,628.9 ms (14.2×) | 5,654.7 ms (49.4×) | — | — |
| `strstarts` | String / REGEX | **28.4 ms (1.0×)** | 6,700.4 ms (235.7×) | — | 1,553.4 ms (54.7×) | 2,925.1 ms (102.9×) | — | — |
| `transitive-path-large-join-and-plus` | Transitive paths | **0.70 ms** | 682.0 ms | — | 136.8 ms | 2,897.1 ms | — | — |
| `transitive-path-plus` | Transitive paths | **0.62 ms** | 0.81 ms | 252.1 ms | — | 0.70 ms | — | — |
| `transitive-path-plus-fixed-subject` | Transitive paths | **0.56 ms** | 0.77 ms | 902.0 ms | 0.96 ms | 0.73 ms | — | — |
| `transitive-path-small-join-and-plus` | Transitive paths | 0.56 ms | 0.95 ms | 248.5 ms | 0.85 ms | **0.48 ms** | 4.60 ms | — |
| `result-size-large` | Result size / export | 479.6 ms (1.5×) | **310.3 ms (1.0×)** | 180.0 s (580.1×) | 17.1 s (55.0×) | 345.0 ms (1.1×) | 155.5 s (501.2×) | — |
| `result-size-medium` | Result size / export | 42.8 ms (1.2×) | 37.5 ms (1.1×) | 48.4 s (1392.8×) | 1,555.2 ms (44.7×) | **34.8 ms (1.0×)** | 6,032.8 ms (173.5×) | — |
| `result-size-small` | Result size / export | 3.63 ms | 2.20 ms | 488.0 ms | 5.25 ms | **0.76 ms** | 5.75 ms | — |
| `result-size-tiny` | Result size / export | 2.65 ms | 1.58 ms | 5.15 ms | 0.89 ms | **0.46 ms** | 4.12 ms | — |
| `result-size-xlarge` | Result size / export | 4,711.3 ms (1.5×) | **3,193.7 ms (1.0×)** | 180.0 s (56.4×) | 17.9 s (5.6×) | 3,472.0 ms (1.1×) | — | — |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 764 s | 0.735 M tr/s | not recorded for this run | 29.69 GB ledger directory | fluree create dblp --from dblp.nt; 561,477,456 distinct statements. Wall time of the import command as timed by the reproduce script (whole seconds), including import completion and statistics; single import measurement. |
| QLever | 521 s | 1.08 M tr/s | 20.8 GB | 9.4 GB | qlever index (native), parallel parse @ 2.3 M/s. in-memory-compressed vocab, num-triples-per-batch 1M (matches the paper). Native on the host needed two things Docker masked: ulimit -n raised to 1048576 (533 partial vocabs) and --stxxl-memory 20G (permutation merge). Loaded 561,477,456 distinct triples. |
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
  - **561,477,456 triples**, 90 predicates, ? subjects, ? objects · on-disk 4.73 GB .nt.gz (5,083,386,634 bytes); ~73.5 GB uncompressed .nt
- **Hardware:** AWS m7a.4xlarge — AMD EPYC (Zen 4), no-SMT, 16 cores, 64 GB RAM, 250 GB gp3 (6000 IOPS / 500 MB/s), Ubuntu 24.04
- **Method:** 1 warmup + 3 timed runs, median reported, 180 s timeout, results as `text/tab-separated-values`
  - Local HTTP, TSV responses, no result cache. One warmup and median of three measured requests, with a 180 s timeout and timed-query wall budget. QLever result cache disabled and cleared per query. QLever and Virtuoso used 300 s caps, but no query finished between 180 and 300 s. Oxigraph uses the single-run protocol described below.

| engine | version | config |
|---|---|---|
| Fluree | v4.2.6 | Official x86_64 Linux release binary, checksum verified. Fresh native import; default auto cache and Sync durability. Local HTTP TSV; no result cache. |
| QLever | git 621cf31 (native) (`621cf31 (native binaries from adfreiburg/qlever:latest image, run directly — no Docker)`) | native; MEMORY_FOR_QUERIES 26G, CACHE_MAX_SIZE 6G (disabled for the benchmark), in-memory-compressed vocab, TIMEOUT 300s — matches ad-freiburg/sparqloscope docs/Qleverfile.dblp |
| Oxigraph | 0.5.8 (native, prebuilt binary) (`oxigraph_v0.5.8_x86_64_linux_gnu (GitHub release)`) | serve-read-only; systemd MemoryMax 52G; no result cache; no server-side query timeout (issue #1336). Sweep methodology DEVIATES from the other engines: warmup 0 + 1 timed run, 180 s timeout, memory-capped with per-query restart-on-failure (mirrors ad-freiburg/sparqloscope util/oxigraph-helper.sh). RocksDB-backed. |
| Virtuoso | 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7) (`07.20.3229`) | 32 GB profile: NumberOfBuffers 2,720,000 (~21 GB), MaxDirtyBuffers 2,000,000, MaxQueryExecutionTime 300 s, ResultSetMaxRows 10M. Data in named graph <https://dblp.org>; queries sent with default-graph-uri. Ubuntu apt 07.20.3229 has a broken ld_dir; data loaded via chunked TTLP(file_to_string(chunk)) in parallel. |
| MillenniumDB | v1.0.0 (built from source) (`github.com/MillenniumDB/MillenniumDB main`) | native; versioned-buffer 22GB, strings-static 4GB, strings-dynamic 4GB; body POST; no result cache. Built on its own m7a.4xlarge (16c/64GB), dblp-core pulled from S3. |
| Jena | Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21) (`6.1.0`) | TDB2 + Fuseki; JVM_ARGS -Xmx32g; body POST; no result cache. Fuseki started cold for benchmark run (no JVM warmup, no OS page cache warmup of 54GB index). |
| Blazegraph | 2.1.6-RC (Java 11) (`BLAZEGRAPH_2_1_6_RC`) | native jar; offline DataLoader on a SKOLEMIZED .nt (blank nodes rewritten to IRIs — required: default load silently drops ALL blank-node triples, 239M/561M); served with -Xmx16g; web.xml queryTimeout 180000; queries via --post-form. Dedicated m7a.4xlarge. |

**Caveats**
- Fluree measured 2026-11-12; other engines measured 2026-06-11. Dedicated hosts of the same instance class, not the same physical host. Absolute timings can vary between hosts.
- All engines use the pinned 2026-06-01 DBLP archive. This differs from the older snapshots used in the SPARQLoscope paper, so absolute timings are not directly comparable to that paper.
- Virtuoso uses chunked TTLP loading; its ld_dir loader was broken in the tested Ubuntu package.
- Jena starts with a cold JVM/TDB cache and a 54 GB index on a 64 GB host; its completion count is cache-state sensitive.
- Oxigraph uses no warmup and one measured request, with a 180 s timeout, a memory cap, and restart on failure. This differs from the other engines' warmup/median-of-three protocol.
- This comparison measures query completion and latency. It does not assert result equivalence across all engines. See the per-query table for differences in performance.
- [Reproduce the Fluree run](v426-release/REPORT.md): pinned binary, dataset and harness checksums, import and query commands.
