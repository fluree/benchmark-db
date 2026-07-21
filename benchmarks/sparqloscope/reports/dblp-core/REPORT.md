# SPARQLoscope benchmark — DBLP-core (bibliography only)

> **Run 2026-06-11 (run dblp-core-20260610-204013); all 7 engines on dedicated m7a.4xlarge boxes, fractional ms precision. Geo mean (P=2, the SPARQLoscope paper's official aggregate; failed query = 2x the 180 s timeout): Fluree v4.1.2 17.5 ms, 105/105. QLever: 202 ms, 105/105. Virtuoso: 300 ms, 103/105 (chunked TTLP loading). MillenniumDB: 1664 ms, 103/105. Jena: 67.7 s, 34/105 (cold TDB cache). Oxigraph: 87.0 s, 39/105. Blazegraph: 333 s, 3/105. Standard DBLP-core (bibliography only, no OpenCitations), stable DROPS archive 2026-06-01 (~561.5M distinct triples). All engines NATIVE (no Docker).**

**Dataset:** 574,218,804 triples, 90 predicates (2026-06-01 (stable DROPS monthly archive)) · **Engines:** Fluree v4.1.2, QLever git 621cf31 (native), Oxigraph 0.5.8 (native, prebuilt binary), Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0 (built from source), Jena Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21), Blazegraph 2.1.6-RC (Java 11) · **Box:** AWS m7a.4xlarge (16c / 64 GB) · 1+3 runs, median, 180 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|
| passed | 105/105 | 105/105 | 39/105 | 103/105 | 103/105 | 34/105 | 3/105 |
| geo mean (P=2) | **17.5 ms (1.0×)** | 202.4 ms (11.5×) | 87.0 s (4960.6×) | 299.7 ms (17.1×) | 1,664.2 ms (94.8×) | 67.7 s (3855.9×) | 332.9 s (18971.1×) |
| geo mean (P=10) | **17.5 ms (1.0×)** | 202.4 ms (11.5×) | 239.4 s (13642.4×) | 309.1 ms (17.6×) | 1,716.0 ms (97.8×) | 200.9 s (11449.0×) | 1589.5 s (90592.6×) |
| geo mean (passed only) | **17.5 ms (1.0×)** | 202.4 ms (11.5×) | 7,874.7 ms (448.8×) | 261.2 ms (14.9×) | 1,499.2 ms (85.4×) | 2,061.7 ms (117.5×) | 23.2 s (1320.4×) |
| arith mean (passed only) | **251.1 ms (1.0×)** | 1,904.3 ms (7.6×) | 36.8 s (146.4×) | 8,020.2 ms (31.9×) | 12.3 s (49.0×) | 31.0 s (123.5×) | 23.2 s (92.3×) |
| median (passed only) | **26.6 ms (1.0×)** | 310.3 ms (11.7×) | 5,089.9 ms (191.6×) | 326.0 ms (12.3×) | 3,894.5 ms (146.6×) | 4,540.7 ms (170.9×) | 23.2 s (871.4×) |

_geo mean (P=2/P=10) is the SPARQLoscope paper's official aggregate: a failed or timed-out query counts as 2× / 10× the 180 s timeout. The passed-only rows average each engine's completed queries only, so they flatter engines with many failures._

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|
| 1.21× | 8.78× | 266.97× | 5.79× | 54.92× | 266.23× | 503.11× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph | fastest |
|---|--:|---|---|---|---|---|---|---|---|
| Dataset statistics | 6 | **1.49 ms** | 13.7 ms | — | 13.3 s | 15.6 s | — | — | Fluree |
| JOIN | 12 | **8.50 ms** | 115.5 ms | 298.3 ms | 41.5 ms | 137.5 ms | 680.7 ms | — | Fluree |
| OPTIONAL | 10 | **43.3 ms (1.0×)** | 507.6 ms (11.7×) | — | 228.1 ms (5.3×) | 7,422.9 ms (171.3×) | — | — | Fluree |
| MINUS | 10 | **46.0 ms (1.0×)** | 518.9 ms (11.3×) | 38.8 s (843.7×) | 214.7 ms (4.7×) | 6,336.7 ms (137.7×) | 103.8 s (2256.3×) | — | Fluree |
| EXISTS | 10 | **47.0 ms (1.0×)** | 712.1 ms (15.2×) | 173.3 s (3687.1×) | 213.9 ms (4.6×) | 6,482.1 ms (137.9×) | 7,635.7 ms (162.5×) | — | Fluree |
| UNION | 5 | **53.2 ms (1.0×)** | 483.1 ms (9.1×) | 100.3 s (1883.5×) | 382.9 ms (7.2×) | 7,263.1 ms (136.4×) | 14.0 s (262.2×) | — | Fluree |
| GROUP BY / aggregate | 16 | **8.12 ms** | 271.8 ms | 15.4 s | 692.6 ms | 2,562.0 ms | 5,175.2 ms | — | Fluree |
| FILTER | 3 | **28.7 ms (1.0×)** | 87.2 ms (3.0×) | — | 1,309.6 ms (45.7×) | 2,407.0 ms (83.9×) | 26.4 s (921.6×) | — | Fluree |
| Numeric functions | 10 | **8.86 ms** | 81.6 ms | 5,034.4 ms | 28.5 ms | 279.6 ms | — | — | Fluree |
| Date functions | 3 | **2.96 ms** | 220.2 ms | 4,844.3 ms | 95.3 ms | 218.3 ms | 2,039.1 ms | 23.2 s | Fluree |
| String / REGEX | 11 | **96.7 ms (1.0×)** | 957.2 ms (9.9×) | — | 1,920.6 ms (19.9×) | 10.8 s (111.3×) | — | — | Fluree |
| Transitive paths | 4 | **0.55 ms** | 4.48 ms | 383.7 ms | 4.81 ms | 5.18 ms | 4.60 ms | — | Fluree |
| Result size / export | 5 | 79.0 ms (2.9×) | 41.9 ms (1.5×) | 5,239.1 ms (193.4×) | 294.7 ms (10.9×) | **27.1 ms (1.0×)** | 386.1 ms (14.3×) | — | MillenniumDB |

### 1c. Per query

| query | category | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **6.53 ms** | 5,164.3 ms | — | 1,383.3 ms | 14.4 s | — | — |
| `number-of-literals` | Dataset statistics | **0.60 ms** | 3,484.3 ms | — | 5,915.1 ms | 13.7 s | — | — |
| `number-of-objects` | Dataset statistics | 1.46 ms | **0.84 ms** | — | — | — | — | — |
| `number-of-predicates` | Dataset statistics | 2.27 ms | **0.70 ms** | — | 57.1 s | 22.4 s | — | — |
| `number-of-subjects` | Dataset statistics | 1.49 ms | **0.82 ms** | — | 177.9 s | — | — | — |
| `number-of-triples` | Dataset statistics | **0.57 ms** | 0.77 ms | — | 5,004.1 ms | 13.4 s | — | — |
| `join-2-large-large` | JOIN | **0.60 ms** | 349.9 ms | — | 920.6 ms | 6,917.4 ms | 80.4 s | — |
| `join-2-large-large-with-large-result` | JOIN | **23.7 ms (1.0×)** | 414.1 ms (17.5×) | — | 853.4 ms (36.1×) | 9,035.7 ms (381.9×) | 93.5 s (3951.7×) | — |
| `join-2-large-large-with-small-result` | JOIN | 58.3 ms | 20.1 ms | — | 17.0 ms | **4.77 ms** | 12.9 s | — |
| `join-2-large-small` | JOIN | **0.57 ms** | 4.51 ms | — | 1.81 ms | 1.96 ms | 8.17 ms | — |
| `join-2-largest-result` | JOIN | **23.4 ms (1.0×)** | 415.0 ms (17.7×) | — | 859.2 ms (36.7×) | 9,029.0 ms (385.9×) | 94.8 s (4052.4×) | — |
| `join-2-small-large` | JOIN | **0.64 ms** | 4.59 ms | — | 1.91 ms | 2.48 ms | 7.80 ms | — |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | **220.6 ms (1.0×)** | 2,587.1 ms (11.7×) | — | 7,458.1 ms (33.8×) | 27.6 s (125.2×) | — | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **127.9 ms (1.0×)** | 2,282.0 ms (17.8×) | — | 232.6 ms (1.8×) | 24.9 s (194.4×) | — | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | 0.84 ms | 453.4 ms | — | **0.83 ms** | 0.84 ms | 10.8 ms | — |
| `join-xlarge-star-on-small-predicates` | JOIN | 1.20 ms | 18.7 ms | — | 0.90 ms | **0.75 ms** | 10.3 ms | — |
| `multicolumn-join-large` | JOIN | 1,112.3 ms (2.0×) | 4,891.1 ms (8.6×) | — | **568.8 ms (1.0×)** | 16.5 s (29.1×) | 69.8 s (122.7×) | — |
| `multicolumn-join-small` | JOIN | 0.63 ms | 0.93 ms | 298.3 ms | 0.90 ms | **0.49 ms** | 4.75 ms | — |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **24.8 ms (1.0×)** | 1,231.6 ms (49.6×) | — | 1,004.9 ms (40.5×) | 12.4 s (501.4×) | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | 65.3 ms (3.3×) | 78.8 ms (4.0×) | — | **19.6 ms (1.0×)** | 2,398.4 ms (122.2×) | — | — |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | 54.7 ms (1.8×) | 39.1 ms (1.3×) | — | **29.9 ms (1.0×)** | 3,877.2 ms (129.5×) | — | — |
| `optional-join-3-chain-1` | OPTIONAL | **221.0 ms (1.0×)** | 2,277.9 ms (10.3×) | — | 2,877.9 ms (13.0×) | 27.7 s (125.4×) | — | — |
| `optional-join-3-chain-2` | OPTIONAL | **839.7 ms (1.0×)** | 8,149.5 ms (9.7×) | — | 2,972.1 ms (3.5×) | 65.1 s (77.5×) | — | — |
| `optional-join-3-star-1` | OPTIONAL | **140.9 ms (1.0×)** | 3,016.6 ms (21.4×) | — | 326.0 ms (2.3×) | 37.6 s (266.6×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **167.7 ms (1.0×)** | 1,720.8 ms (10.3×) | — | 351.8 ms (2.1×) | 20.9 s (124.8×) | — | — |
| `optional-join-large-large` | OPTIONAL | **144.4 ms (1.0×)** | 1,466.5 ms (10.2×) | — | 690.7 ms (4.8×) | 43.9 s (303.9×) | — | — |
| `optional-join-large-small` | OPTIONAL | **0.68 ms** | 462.7 ms | — | 490.9 ms | 42.7 s | — | — |
| `optional-join-small-large` | OPTIONAL | **0.61 ms** | 4.58 ms | — | 1.94 ms | 1.65 ms | — | — |
| `minus-join-2-large-large-with-large-result` | MINUS | **21.0 ms (1.0×)** | 425.2 ms (20.2×) | 110.3 s (5245.8×) | 1,011.0 ms (48.1×) | 8,773.8 ms (417.3×) | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | 26.0 ms (1.3×) | 47.7 ms (2.4×) | 8,673.7 ms (436.7×) | **19.9 ms (1.0×)** | 2,389.1 ms (120.3×) | — | — |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **25.8 ms (1.0×)** | 61.8 ms (2.4×) | 7,020.9 ms (272.0×) | 30.1 ms (1.2×) | 3,888.2 ms (150.6×) | — | — |
| `minus-join-3-chain-1` | MINUS | **210.1 ms (1.0×)** | 1,406.7 ms (6.7×) | — | 2,880.3 ms (13.7×) | 20.5 s (97.5×) | 103.8 s (494.1×) | — |
| `minus-join-3-chain-2` | MINUS | **2,396.4 ms (1.0×)** | 8,650.5 ms (3.6×) | — | 2,914.6 ms (1.2×) | 25.5 s (10.6×) | — | — |
| `minus-join-3-star-1` | MINUS | 1,692.8 ms (5.4×) | 2,120.4 ms (6.8×) | — | **314.0 ms (1.0×)** | 36.0 s (114.7×) | — | — |
| `minus-join-3-star-2` | MINUS | **75.2 ms (1.0×)** | 2,031.3 ms (27.0×) | — | 231.6 ms (3.1×) | 19.2 s (255.7×) | — | — |
| `minus-join-large-large` | MINUS | **114.3 ms (1.0×)** | 810.7 ms (7.1×) | 177.1 s (1549.3×) | 618.5 ms (5.4×) | 41.5 s (362.9×) | — | — |
| `minus-join-large-small` | MINUS | **0.68 ms** | 611.0 ms | 74.1 s | 464.1 ms | 41.3 s | — | — |
| `minus-join-small-large` | MINUS | **0.60 ms** | 43.5 ms | — | 1.96 ms | 2.06 ms | — | — |
| `exists-join-2-large-large-with-large-result` | EXISTS | **25.9 ms (1.0×)** | 788.6 ms (30.4×) | — | 957.2 ms (36.9×) | 9,070.8 ms (350.0×) | 79.0 s (3047.5×) | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | 26.0 ms (1.4×) | 59.6 ms (3.3×) | — | **18.1 ms (1.0×)** | 2,378.4 ms (131.5×) | 13.9 s (768.3×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **25.7 ms (1.0×)** | 59.9 ms (2.3×) | — | 31.4 ms (1.2×) | 3,894.5 ms (151.4×) | 14.0 s (546.0×) | — |
| `exists-join-3-chain-1` | EXISTS | **217.5 ms (1.0×)** | 3,693.2 ms (17.0×) | — | 12.0 s (55.1×) | 21.4 s (98.3×) | 170.0 s (781.7×) | — |
| `exists-join-3-chain-2` | EXISTS | **2,372.3 ms (1.0×)** | 10.2 s (4.3×) | — | 171.6 s (72.3×) | 25.9 s (10.9×) | — | — |
| `exists-join-3-star-1` | EXISTS | 1,610.6 ms (4.6×) | 2,607.1 ms (7.4×) | — | **352.1 ms (1.0×)** | 37.3 s (106.0×) | — | — |
| `exists-join-3-star-2` | EXISTS | **75.9 ms (1.0×)** | 2,412.3 ms (31.8×) | — | 240.0 ms (3.2×) | 19.8 s (260.9×) | — | — |
| `exists-join-large-large` | EXISTS | **118.1 ms (1.0×)** | 851.3 ms (7.2×) | — | 629.4 ms (5.3×) | 40.8 s (345.6×) | — | — |
| `exists-join-large-small` | EXISTS | **0.68 ms** | 469.8 ms | — | 1.89 ms | 40.5 s | — | — |
| `exists-join-small-large` | EXISTS | **0.60 ms** | 126.1 ms | 173.3 s | 1.79 ms | 2.31 ms | 9.90 ms | — |
| `union-constraint-filter-restrictive` | UNION | 1,283.0 ms (2.2×) | 944.1 ms (1.6×) | — | **581.6 ms (1.0×)** | 4,106.1 ms (7.1×) | 14.0 s (24.0×) | — |
| `union-constraint-from-star` | UNION | **120.5 ms (1.0×)** | 1,323.6 ms (11.0×) | — | 374.9 ms (3.1×) | 31.4 s (260.3×) | — | — |
| `union-constraint-large-join` | UNION | **203.5 ms (1.0×)** | 764.2 ms (3.8×) | — | 1,803.9 ms (8.9×) | 16.4 s (80.6×) | — | — |
| `union-constraint-small-join` | UNION | **22.1 ms (1.0×)** | 117.3 ms (5.3×) | — | 35.6 ms (1.6×) | 2,239.8 ms (101.4×) | — | — |
| `union-no-constraint` | UNION | **0.61 ms** | 234.7 ms | 100.3 s | 586.8 ms | 4,270.5 ms | — | — |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **0.81 ms** | 2,478.2 ms | 69.1 s | 11.3 s | 4,274.4 ms | 21.9 s | — |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **0.81 ms** | 12.9 s | 31.8 s | 36.1 s | 78.6 s | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 1,049.9 ms (1.0×) | **1,044.0 ms (1.0×)** | — | 2,902.4 ms (2.8×) | 6,752.3 ms (6.5×) | 30.1 s (28.8×) | — |
| `group-by-complex-aggregate` | GROUP BY / aggregate | **374.4 ms (1.0×)** | 1,962.3 ms (5.2×) | — | 39.3 s (105.1×) | 18.7 s (49.9×) | — | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | **4.22 ms** | 10.5 ms | 81.1 s | 185.5 ms | 3,858.2 ms | — | — |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **138.8 ms (1.0×)** | 1,927.6 ms (13.9×) | 81.6 s (588.1×) | 6,776.0 ms (48.8×) | 28.0 s (201.9×) | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | 359.4 ms (5.3×) | 1,513.6 ms (22.4×) | — | **67.5 ms (1.0×)** | 6,528.8 ms (96.8×) | — | — |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | **58.3 ms (1.0×)** | 85.4 ms (1.5×) | 5,831.3 ms (100.0×) | 193.0 ms (3.3×) | 255.4 ms (4.4×) | 2,807.0 ms (48.1×) | — |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | **0.60 ms** | 2.29 ms | 4,461.0 ms | 5.96 ms | 229.5 ms | 2,646.3 ms | — |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **0.55 ms** | 79.1 ms | 4,660.8 ms | 78.5 ms | 245.9 ms | 2,506.7 ms | — |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **0.57 ms** | 79.0 ms | 4,706.0 ms | 80.1 ms | 264.4 ms | 3,048.5 ms | — |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | **40.6 ms (1.0×)** | 85.1 ms (2.1×) | 4,726.4 ms (116.5×) | 130.1 ms (3.2×) | 255.2 ms (6.3×) | 2,663.2 ms (65.6×) | — |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | **0.62 ms** | 2.29 ms | 18.9 s | 81.0 ms | 766.9 ms | — | — |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **0.75 ms** | 262.4 ms | — | 281.2 ms | 1,697.4 ms | — | — |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **0.67 ms** | 262.4 ms | — | 205.5 ms | 1,553.5 ms | — | — |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **48.1 ms (1.0×)** | 26.8 s (557.2×) | — | 161.9 s (3367.7×) | 58.6 s (1218.5×) | — | — |
| `filter-few-results` | FILTER | **143.1 ms (1.0×)** | 766.5 ms (5.4×) | — | 223.7 ms (1.6×) | 3,328.4 ms (23.3×) | 11.0 s (76.6×) | — |
| `filter-language-en` | FILTER | 1.13 ms | **0.90 ms** | — | 38.6 s | 823.0 ms | 63.7 s | — |
| `filter-many-results` | FILTER | **145.4 ms (1.0×)** | 963.4 ms (6.6×) | — | 260.3 ms (1.8×) | 5,090.9 ms (35.0×) | — | — |
| `numeric-abs` | Numeric functions | **42.5 ms (1.0×)** | 188.8 ms (4.4×) | 5,742.0 ms (135.0×) | 43.1 ms (1.0×) | 297.6 ms (7.0×) | — | — |
| `numeric-add` | Numeric functions | 41.8 ms (1.6×) | 258.7 ms (9.9×) | 5,186.1 ms (198.4×) | **26.1 ms (1.0×)** | 323.1 ms (12.4×) | — | — |
| `numeric-baseline` | Numeric functions | **40.6 ms (1.0×)** | 85.1 ms (2.1×) | 4,730.2 ms (116.4×) | 125.4 ms (3.1×) | 255.3 ms (6.3×) | — | — |
| `numeric-ceil` | Numeric functions | **42.6 ms (1.0×)** | 189.0 ms (4.4×) | 4,937.8 ms (115.9×) | 64.9 ms (1.5×) | 295.2 ms (6.9×) | — | — |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **0.84 ms** | 30.9 ms | 5,089.9 ms | 13.7 ms | 307.6 ms | — | — |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | **0.92 ms** | 5.33 ms | 4,874.0 ms | 3.40 ms | 235.8 ms | — | — |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | **0.77 ms** | 23.6 ms | 5,006.6 ms | 10.7 ms | 286.2 ms | — | — |
| `numeric-floor` | Numeric functions | **42.6 ms (1.0×)** | 188.3 ms (4.4×) | 4,977.2 ms (116.8×) | 65.1 ms (1.5×) | 297.4 ms (7.0×) | — | — |
| `numeric-greater` | Numeric functions | **0.90 ms** | 121.2 ms | 4,916.7 ms | 17.7 ms | 219.9 ms | — | — |
| `numeric-round` | Numeric functions | **42.6 ms (1.0×)** | 188.0 ms (4.4×) | 4,946.8 ms (116.1×) | 66.3 ms (1.6×) | 297.2 ms (7.0×) | — | — |
| `date-day` | Date functions | **0.81 ms** | 234.7 ms | 4,580.7 ms | 95.5 ms | 218.2 ms | 1,654.5 ms | 23.2 s |
| `date-month` | Date functions | **0.69 ms** | 234.7 ms | 4,503.5 ms | 97.1 ms | 218.3 ms | 2,476.8 ms | 23.3 s |
| `date-year` | Date functions | **45.8 ms (1.0×)** | 193.9 ms (4.2×) | 5,510.8 ms (120.4×) | 93.2 ms (2.0×) | 218.3 ms (4.8×) | 2,069.0 ms (45.2×) | 23.0 s (503.1×) |
| `regex-3` | String / REGEX | **481.6 ms (1.0×)** | 7,380.6 ms (15.3×) | — | 9,067.5 ms (18.8×) | 21.1 s (43.9×) | — | — |
| `regex-3-contains` | String / REGEX | **109.6 ms (1.0×)** | 6,897.3 ms (62.9×) | — | 1,554.1 ms (14.2×) | 2,892.7 ms (26.4×) | — | — |
| `regex-3-fixed` | String / REGEX | **407.2 ms (1.0×)** | 7,359.1 ms (18.1×) | — | 1,709.3 ms (4.2×) | 21.3 s (52.2×) | — | — |
| `regex-prefix-1` | String / REGEX | 181.0 ms | **6.72 ms** | — | 1,793.7 ms | 19.6 s | — | — |
| `regex-prefix-2` | String / REGEX | 26.6 ms | **3.96 ms** | — | 1,720.7 ms | 20.8 s | — | — |
| `regex-prefix-3` | String / REGEX | 10.2 ms | **1.76 ms** | — | 1,675.7 ms | 21.3 s | — | — |
| `strafter` | String / REGEX | **129.7 ms (1.0×)** | 10.9 s (84.2×) | — | 1,702.7 ms (13.1×) | 34.5 s (265.7×) | — | — |
| `strbefore` | String / REGEX | **118.5 ms (1.0×)** | 10.1 s (85.0×) | — | 1,568.5 ms (13.2×) | 11.9 s (100.5×) | — | — |
| `strends` | String / REGEX | **97.0 ms (1.0×)** | 6,720.6 ms (69.3×) | — | 1,557.6 ms (16.1×) | 2,919.0 ms (30.1×) | — | — |
| `strlen` | String / REGEX | **104.9 ms (1.0×)** | 7,098.8 ms (67.7×) | — | 1,628.9 ms (15.5×) | 5,654.7 ms (53.9×) | — | — |
| `strstarts` | String / REGEX | **41.9 ms (1.0×)** | 6,700.4 ms (159.8×) | — | 1,553.4 ms (37.1×) | 2,925.1 ms (69.8×) | — | — |
| `transitive-path-large-join-and-plus` | Transitive paths | **0.56 ms** | 682.0 ms | — | 136.8 ms | 2,897.1 ms | — | — |
| `transitive-path-plus` | Transitive paths | **0.55 ms** | 0.81 ms | 252.1 ms | — | 0.70 ms | — | — |
| `transitive-path-plus-fixed-subject` | Transitive paths | **0.50 ms** | 0.77 ms | 902.0 ms | 0.96 ms | 0.73 ms | — | — |
| `transitive-path-small-join-and-plus` | Transitive paths | 0.59 ms | 0.95 ms | 248.5 ms | 0.85 ms | **0.48 ms** | 4.60 ms | — |
| `result-size-large` | Result size / export | 715.5 ms (2.3×) | **310.3 ms (1.0×)** | 180.0 s (580.1×) | 17.1 s (55.0×) | 345.0 ms (1.1×) | 155.5 s (501.2×) | — |
| `result-size-medium` | Result size / export | 61.8 ms (1.8×) | 37.5 ms (1.1×) | 48.4 s (1392.8×) | 1,555.2 ms (44.7×) | **34.8 ms (1.0×)** | 6,032.8 ms (173.5×) | — |
| `result-size-small` | Result size / export | 3.55 ms | 2.20 ms | 488.0 ms | 5.25 ms | **0.76 ms** | 5.75 ms | — |
| `result-size-tiny` | Result size / export | 2.68 ms | 1.58 ms | 5.15 ms | 0.89 ms | **0.46 ms** | 4.12 ms | — |
| `result-size-xlarge` | Result size / export | 7,288.6 ms (2.3×) | **3,193.7 ms (1.0×)** | 180.0 s (56.4×) | 17.9 s (5.6×) | 3,472.0 ms (1.1×) | — | — |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 672 s | 0.835 M tr/s | ? | ? | fluree create dblp --from dblp.nt on the m7a.4xlarge box; 561,544,658 distinct triples in 672 s (0.835 M tr/s). Import is single-threaded and I/O-bound; query latency is unaffected (see status). Peak RAM / index size not separately captured for this run. |
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
| Fluree | v4.1.2 | Server cache auto (~31.5 GB); inline-indexed ledger. Built from source (branch feature/cypher-import @ d9f36463, pre-release v4.1.2 — carries the warm-on-write read cache + filtered-DELETE staging fix). Uses the metadata-driven fast paths (literals, subjects, objects, MIN/MAX string, COUNT DISTINCT) and algebraic aggregate identities. Query geo mean 17.5 ms, 105/105 — best of all measured Fluree versions. |
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
