# SPARQLoscope benchmark — DBLP-core (bibliography only)

> **Fluree v4.2.0: 105/105 queries, 17.5 ms geometric mean; QLever 202.4 ms and Virtuoso 299.7 ms. Native engines on matching m7a.4xlarge hardware, using the same DBLP snapshot and 105 queries.**

**Dataset:** 561,477,456 triples, 90 predicates (2026-06-01 (stable DROPS monthly archive)) · **Engines:** Fluree v4.2.0, QLever git 621cf31 (native), Oxigraph 0.5.8 (native, prebuilt binary), Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0 (built from source), Jena Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21), Blazegraph 2.1.6-RC (Java 11) · **Box:** AWS m7a.4xlarge (16c / 64 GB) · 1+3 runs, median, 180 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|
| passed | 105/105 | 105/105 | 39/105 | 103/105 | 103/105 | 34/105 | 3/105 |
| geo mean (P=2) | **17.5 ms (1.0×)** | 202.4 ms (11.5×) | 87.0 s (4965.6×) | 299.7 ms (17.1×) | 1,664.2 ms (94.9×) | 67.7 s (3859.8×) | 332.9 s (18990.3×) |
| geo mean (P=10) | **17.5 ms (1.0×)** | 202.4 ms (11.5×) | 239.4 s (13656.2×) | 309.1 ms (17.6×) | 1,716.0 ms (97.9×) | 200.9 s (11460.6×) | 1589.5 s (90684.1×) |
| geo mean (passed only) | **17.5 ms (1.0×)** | 202.4 ms (11.5×) | 7,874.7 ms (449.3×) | 261.2 ms (14.9×) | 1,499.2 ms (85.5×) | 2,061.7 ms (117.6×) | 23.2 s (1321.8×) |
| arith mean (passed only) | **243.8 ms (1.0×)** | 1,904.3 ms (7.8×) | 36.8 s (150.7×) | 8,020.2 ms (32.9×) | 12.3 s (50.5×) | 31.0 s (127.2×) | 23.2 s (95.0×) |
| median (passed only) | **27.0 ms (1.0×)** | 310.3 ms (11.5×) | 5,089.9 ms (188.2×) | 326.0 ms (12.1×) | 3,894.5 ms (144.0×) | 4,540.7 ms (167.9×) | 23.2 s (856.0×) |

_geo mean (P=2/P=10) is the SPARQLoscope paper's official aggregate: a failed or timed-out query counts as 2× / 10× the 180 s timeout. The passed-only rows average each engine's completed queries only, so they flatter engines with many failures._

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|
| 1.18× | 8.81× | 278.33× | 5.81× | 55.11× | 281.03× | 597.45× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph | fastest |
|---|--:|---|---|---|---|---|---|---|---|
| Dataset statistics | 6 | **1.20 ms** | 13.7 ms | — | 13.3 s | 15.6 s | — | — | Fluree |
| JOIN | 12 | **8.31 ms** | 115.5 ms | 298.3 ms | 41.5 ms | 137.5 ms | 680.7 ms | — | Fluree |
| OPTIONAL | 10 | **40.0 ms (1.0×)** | 507.6 ms (12.7×) | — | 228.1 ms (5.7×) | 7,422.9 ms (185.7×) | — | — | Fluree |
| MINUS | 10 | **46.9 ms (1.0×)** | 518.9 ms (11.1×) | 38.8 s (827.3×) | 214.7 ms (4.6×) | 6,336.7 ms (135.1×) | 103.8 s (2212.7×) | — | Fluree |
| EXISTS | 10 | **47.7 ms (1.0×)** | 712.1 ms (14.9×) | 173.3 s (3628.8×) | 213.9 ms (4.5×) | 6,482.1 ms (135.8×) | 7,635.7 ms (159.9×) | — | Fluree |
| UNION | 5 | **50.5 ms (1.0×)** | 483.1 ms (9.6×) | 100.3 s (1986.8×) | 382.9 ms (7.6×) | 7,263.1 ms (143.9×) | 14.0 s (276.6×) | — | Fluree |
| GROUP BY / aggregate | 16 | **8.01 ms** | 271.8 ms | 15.4 s | 692.6 ms | 2,562.0 ms | 5,175.2 ms | — | Fluree |
| FILTER | 3 | **29.1 ms (1.0×)** | 87.2 ms (3.0×) | — | 1,309.6 ms (45.0×) | 2,407.0 ms (82.8×) | 26.4 s (909.0×) | — | Fluree |
| Numeric functions | 10 | **8.90 ms** | 81.6 ms | 5,034.4 ms | 28.5 ms | 279.6 ms | — | — | Fluree |
| Date functions | 3 | **2.95 ms** | 220.2 ms | 4,844.3 ms | 95.3 ms | 218.3 ms | 2,039.1 ms | 23.2 s | Fluree |
| String / REGEX | 11 | **100.3 ms (1.0×)** | 957.2 ms (9.5×) | — | 1,920.6 ms (19.1×) | 10.8 s (107.2×) | — | — | Fluree |
| Transitive paths | 4 | **0.60 ms** | 4.48 ms | 383.7 ms | 4.81 ms | 5.18 ms | 4.60 ms | — | Fluree |
| Result size / export | 5 | 108.5 ms (4.0×) | 41.9 ms (1.5×) | 5,239.1 ms (193.4×) | 294.7 ms (10.9×) | **27.1 ms (1.0×)** | 386.1 ms (14.3×) | — | MillenniumDB |

### 1c. Per query

| query | category | Fluree | QLever | Oxigraph | Virtuoso | MillenniumDB | Jena | Blazegraph |
|---|---|---|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | **6.48 ms** | 5,164.3 ms | — | 1,383.3 ms | 14.4 s | — | — |
| `number-of-literals` | Dataset statistics | **0.51 ms** | 3,484.3 ms | — | 5,915.1 ms | 13.7 s | — | — |
| `number-of-objects` | Dataset statistics | 1.57 ms | **0.84 ms** | — | — | — | — | — |
| `number-of-predicates` | Dataset statistics | **0.56 ms** | 0.70 ms | — | 57.1 s | 22.4 s | — | — |
| `number-of-subjects` | Dataset statistics | 1.64 ms | **0.82 ms** | — | 177.9 s | — | — | — |
| `number-of-triples` | Dataset statistics | **0.61 ms** | 0.77 ms | — | 5,004.1 ms | 13.4 s | — | — |
| `join-2-large-large` | JOIN | **0.66 ms** | 349.9 ms | — | 920.6 ms | 6,917.4 ms | 80.4 s | — |
| `join-2-large-large-with-large-result` | JOIN | **22.7 ms (1.0×)** | 414.1 ms (18.2×) | — | 853.4 ms (37.6×) | 9,035.7 ms (397.6×) | 93.5 s (4113.9×) | — |
| `join-2-large-large-with-small-result` | JOIN | 48.1 ms | 20.1 ms | — | 17.0 ms | **4.77 ms** | 12.9 s | — |
| `join-2-large-small` | JOIN | **0.64 ms** | 4.51 ms | — | 1.81 ms | 1.96 ms | 8.17 ms | — |
| `join-2-largest-result` | JOIN | **22.6 ms (1.0×)** | 415.0 ms (18.4×) | — | 859.2 ms (38.0×) | 9,029.0 ms (399.7×) | 94.8 s (4197.9×) | — |
| `join-2-small-large` | JOIN | **0.58 ms** | 4.59 ms | — | 1.91 ms | 2.48 ms | 7.80 ms | — |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | **235.0 ms (1.0×)** | 2,587.1 ms (11.0×) | — | 7,458.1 ms (31.7×) | 27.6 s (117.5×) | — | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **111.2 ms (1.0×)** | 2,282.0 ms (20.5×) | — | 232.6 ms (2.1×) | 24.9 s (223.6×) | — | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | 0.90 ms | 453.4 ms | — | **0.83 ms** | 0.84 ms | 10.8 ms | — |
| `join-xlarge-star-on-small-predicates` | JOIN | 1.01 ms | 18.7 ms | — | 0.90 ms | **0.75 ms** | 10.3 ms | — |
| `multicolumn-join-large` | JOIN | 1,117.4 ms (2.0×) | 4,891.1 ms (8.6×) | — | **568.8 ms (1.0×)** | 16.5 s (29.1×) | 69.8 s (122.7×) | — |
| `multicolumn-join-small` | JOIN | 0.68 ms | 0.93 ms | 298.3 ms | 0.90 ms | **0.49 ms** | 4.75 ms | — |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **24.1 ms (1.0×)** | 1,231.6 ms (51.2×) | — | 1,004.9 ms (41.8×) | 12.4 s (517.4×) | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | 37.2 ms (1.9×) | 78.8 ms (4.0×) | — | **19.6 ms (1.0×)** | 2,398.4 ms (122.2×) | — | — |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | 31.3 ms (1.0×) | 39.1 ms (1.3×) | — | **29.9 ms (1.0×)** | 3,877.2 ms (129.5×) | — | — |
| `optional-join-3-chain-1` | OPTIONAL | **234.3 ms (1.0×)** | 2,277.9 ms (9.7×) | — | 2,877.9 ms (12.3×) | 27.7 s (118.2×) | — | — |
| `optional-join-3-chain-2` | OPTIONAL | **853.6 ms (1.0×)** | 8,149.5 ms (9.5×) | — | 2,972.1 ms (3.5×) | 65.1 s (76.2×) | — | — |
| `optional-join-3-star-1` | OPTIONAL | **116.7 ms (1.0×)** | 3,016.6 ms (25.9×) | — | 326.0 ms (2.8×) | 37.6 s (322.0×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **245.6 ms (1.0×)** | 1,720.8 ms (7.0×) | — | 351.8 ms (1.4×) | 20.9 s (85.3×) | — | — |
| `optional-join-large-large` | OPTIONAL | **133.5 ms (1.0×)** | 1,466.5 ms (11.0×) | — | 690.7 ms (5.2×) | 43.9 s (328.8×) | — | — |
| `optional-join-large-small` | OPTIONAL | **0.65 ms** | 462.7 ms | — | 490.9 ms | 42.7 s | — | — |
| `optional-join-small-large` | OPTIONAL | **0.75 ms** | 4.58 ms | — | 1.94 ms | 1.65 ms | — | — |
| `minus-join-2-large-large-with-large-result` | MINUS | **21.0 ms (1.0×)** | 425.2 ms (20.2×) | 110.3 s (5241.6×) | 1,011.0 ms (48.0×) | 8,773.8 ms (417.0×) | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | 26.6 ms (1.3×) | 47.7 ms (2.4×) | 8,673.7 ms (436.7×) | **19.9 ms (1.0×)** | 2,389.1 ms (120.3×) | — | — |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **25.8 ms (1.0×)** | 61.8 ms (2.4×) | 7,020.9 ms (272.2×) | 30.1 ms (1.2×) | 3,888.2 ms (150.8×) | — | — |
| `minus-join-3-chain-1` | MINUS | **217.4 ms (1.0×)** | 1,406.7 ms (6.5×) | — | 2,880.3 ms (13.3×) | 20.5 s (94.2×) | 103.8 s (477.5×) | — |
| `minus-join-3-chain-2` | MINUS | **2,381.4 ms (1.0×)** | 8,650.5 ms (3.6×) | — | 2,914.6 ms (1.2×) | 25.5 s (10.7×) | — | — |
| `minus-join-3-star-1` | MINUS | 1,694.6 ms (5.4×) | 2,120.4 ms (6.8×) | — | **314.0 ms (1.0×)** | 36.0 s (114.7×) | — | — |
| `minus-join-3-star-2` | MINUS | **93.2 ms (1.0×)** | 2,031.3 ms (21.8×) | — | 231.6 ms (2.5×) | 19.2 s (206.4×) | — | — |
| `minus-join-large-large` | MINUS | **111.4 ms (1.0×)** | 810.7 ms (7.3×) | 177.1 s (1589.9×) | 618.5 ms (5.6×) | 41.5 s (372.4×) | — | — |
| `minus-join-large-small` | MINUS | **0.63 ms** | 611.0 ms | 74.1 s | 464.1 ms | 41.3 s | — | — |
| `minus-join-small-large` | MINUS | **0.62 ms** | 43.5 ms | — | 1.96 ms | 2.06 ms | — | — |
| `exists-join-2-large-large-with-large-result` | EXISTS | **20.6 ms (1.0×)** | 788.6 ms (38.2×) | — | 957.2 ms (46.4×) | 9,070.8 ms (439.8×) | 79.0 s (3829.7×) | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | 25.2 ms (1.4×) | 59.6 ms (3.3×) | — | **18.1 ms (1.0×)** | 2,378.4 ms (131.5×) | 13.9 s (768.3×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **25.7 ms (1.0×)** | 59.9 ms (2.3×) | — | 31.4 ms (1.2×) | 3,894.5 ms (151.6×) | 14.0 s (546.7×) | — |
| `exists-join-3-chain-1` | EXISTS | **231.2 ms (1.0×)** | 3,693.2 ms (16.0×) | — | 12.0 s (51.8×) | 21.4 s (92.5×) | 170.0 s (735.4×) | — |
| `exists-join-3-chain-2` | EXISTS | **2,394.1 ms (1.0×)** | 10.2 s (4.3×) | — | 171.6 s (71.7×) | 25.9 s (10.8×) | — | — |
| `exists-join-3-star-1` | EXISTS | 1,618.5 ms (4.6×) | 2,607.1 ms (7.4×) | — | **352.1 ms (1.0×)** | 37.3 s (106.0×) | — | — |
| `exists-join-3-star-2` | EXISTS | **90.8 ms (1.0×)** | 2,412.3 ms (26.6×) | — | 240.0 ms (2.6×) | 19.8 s (217.9×) | — | — |
| `exists-join-large-large` | EXISTS | **116.1 ms (1.0×)** | 851.3 ms (7.3×) | — | 629.4 ms (5.4×) | 40.8 s (351.5×) | — | — |
| `exists-join-large-small` | EXISTS | **0.70 ms** | 469.8 ms | — | 1.89 ms | 40.5 s | — | — |
| `exists-join-small-large` | EXISTS | **0.69 ms** | 126.1 ms | 173.3 s | 1.79 ms | 2.31 ms | 9.90 ms | — |
| `union-constraint-filter-restrictive` | UNION | 1,234.8 ms (2.1×) | 944.1 ms (1.6×) | — | **581.6 ms (1.0×)** | 4,106.1 ms (7.1×) | 14.0 s (24.0×) | — |
| `union-constraint-from-star` | UNION | **123.4 ms (1.0×)** | 1,323.6 ms (10.7×) | — | 374.9 ms (3.0×) | 31.4 s (254.1×) | — | — |
| `union-constraint-large-join` | UNION | **192.0 ms (1.0×)** | 764.2 ms (4.0×) | — | 1,803.9 ms (9.4×) | 16.4 s (85.5×) | — | — |
| `union-constraint-small-join` | UNION | **18.9 ms (1.0×)** | 117.3 ms (6.2×) | — | 35.6 ms (1.9×) | 2,239.8 ms (118.3×) | — | — |
| `union-no-constraint` | UNION | **0.59 ms** | 234.7 ms | 100.3 s | 586.8 ms | 4,270.5 ms | — | — |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | **0.85 ms** | 2,478.2 ms | 69.1 s | 11.3 s | 4,274.4 ms | 21.9 s | — |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | **0.86 ms** | 12.9 s | 31.8 s | 36.1 s | 78.6 s | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 1,046.5 ms (1.0×) | **1,044.0 ms (1.0×)** | — | 2,902.4 ms (2.8×) | 6,752.3 ms (6.5×) | 30.1 s (28.8×) | — |
| `group-by-complex-aggregate` | GROUP BY / aggregate | **361.8 ms (1.0×)** | 1,962.3 ms (5.4×) | — | 39.3 s (108.7×) | 18.7 s (51.6×) | — | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | **4.14 ms** | 10.5 ms | 81.1 s | 185.5 ms | 3,858.2 ms | — | — |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **149.9 ms (1.0×)** | 1,927.6 ms (12.9×) | 81.6 s (544.8×) | 6,776.0 ms (45.2×) | 28.0 s (187.0×) | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | 346.1 ms (5.1×) | 1,513.6 ms (22.4×) | — | **67.5 ms (1.0×)** | 6,528.8 ms (96.8×) | — | — |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | **37.0 ms (1.0×)** | 85.4 ms (2.3×) | 5,831.3 ms (157.5×) | 193.0 ms (5.2×) | 255.4 ms (6.9×) | 2,807.0 ms (75.8×) | — |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | **0.55 ms** | 2.29 ms | 4,461.0 ms | 5.96 ms | 229.5 ms | 2,646.3 ms | — |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **0.66 ms** | 79.1 ms | 4,660.8 ms | 78.5 ms | 245.9 ms | 2,506.7 ms | — |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **0.70 ms** | 79.0 ms | 4,706.0 ms | 80.1 ms | 264.4 ms | 3,048.5 ms | — |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | **39.4 ms (1.0×)** | 85.1 ms (2.2×) | 4,726.4 ms (120.0×) | 130.1 ms (3.3×) | 255.2 ms (6.5×) | 2,663.2 ms (67.6×) | — |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | **0.58 ms** | 2.29 ms | 18.9 s | 81.0 ms | 766.9 ms | — | — |
| `group-by-implicit-string-max` | GROUP BY / aggregate | **0.85 ms** | 262.4 ms | — | 281.2 ms | 1,697.4 ms | — | — |
| `group-by-implicit-string-min` | GROUP BY / aggregate | **0.52 ms** | 262.4 ms | — | 205.5 ms | 1,553.5 ms | — | — |
| `group-by-string-groupconcat` | GROUP BY / aggregate | **49.7 ms (1.0×)** | 26.8 s (539.4×) | — | 161.9 s (3260.0×) | 58.6 s (1179.5×) | — | — |
| `filter-few-results` | FILTER | **143.2 ms (1.0×)** | 766.5 ms (5.4×) | — | 223.7 ms (1.6×) | 3,328.4 ms (23.2×) | 11.0 s (76.5×) | — |
| `filter-language-en` | FILTER | 1.18 ms | **0.90 ms** | — | 38.6 s | 823.0 ms | 63.7 s | — |
| `filter-many-results` | FILTER | **145.5 ms (1.0×)** | 963.4 ms (6.6×) | — | 260.3 ms (1.8×) | 5,090.9 ms (35.0×) | — | — |
| `numeric-abs` | Numeric functions | **41.9 ms (1.0×)** | 188.8 ms (4.5×) | 5,742.0 ms (137.2×) | 43.1 ms (1.0×) | 297.6 ms (7.1×) | — | — |
| `numeric-add` | Numeric functions | 40.4 ms (1.5×) | 258.7 ms (9.9×) | 5,186.1 ms (198.4×) | **26.1 ms (1.0×)** | 323.1 ms (12.4×) | — | — |
| `numeric-baseline` | Numeric functions | **39.4 ms (1.0×)** | 85.1 ms (2.2×) | 4,730.2 ms (120.0×) | 125.4 ms (3.2×) | 255.3 ms (6.5×) | — | — |
| `numeric-ceil` | Numeric functions | **41.7 ms (1.0×)** | 189.0 ms (4.5×) | 4,937.8 ms (118.3×) | 64.9 ms (1.6×) | 295.2 ms (7.1×) | — | — |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **0.92 ms** | 30.9 ms | 5,089.9 ms | 13.7 ms | 307.6 ms | — | — |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | **0.82 ms** | 5.33 ms | 4,874.0 ms | 3.40 ms | 235.8 ms | — | — |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | **0.93 ms** | 23.6 ms | 5,006.6 ms | 10.7 ms | 286.2 ms | — | — |
| `numeric-floor` | Numeric functions | **41.9 ms (1.0×)** | 188.3 ms (4.5×) | 4,977.2 ms (118.9×) | 65.1 ms (1.6×) | 297.4 ms (7.1×) | — | — |
| `numeric-greater` | Numeric functions | **0.92 ms** | 121.2 ms | 4,916.7 ms | 17.7 ms | 219.9 ms | — | — |
| `numeric-round` | Numeric functions | **41.8 ms (1.0×)** | 188.0 ms (4.5×) | 4,946.8 ms (118.4×) | 66.3 ms (1.6×) | 297.2 ms (7.1×) | — | — |
| `date-day` | Date functions | **0.96 ms** | 234.7 ms | 4,580.7 ms | 95.5 ms | 218.2 ms | 1,654.5 ms | 23.2 s |
| `date-month` | Date functions | **0.69 ms** | 234.7 ms | 4,503.5 ms | 97.1 ms | 218.3 ms | 2,476.8 ms | 23.3 s |
| `date-year` | Date functions | **38.5 ms (1.0×)** | 193.9 ms (5.0×) | 5,510.8 ms (143.0×) | 93.2 ms (2.4×) | 218.3 ms (5.7×) | 2,069.0 ms (53.7×) | 23.0 s (597.5×) |
| `regex-3` | String / REGEX | **485.4 ms (1.0×)** | 7,380.6 ms (15.2×) | — | 9,067.5 ms (18.7×) | 21.1 s (43.5×) | — | — |
| `regex-3-contains` | String / REGEX | **112.7 ms (1.0×)** | 6,897.3 ms (61.2×) | — | 1,554.1 ms (13.8×) | 2,892.7 ms (25.7×) | — | — |
| `regex-3-fixed` | String / REGEX | **402.0 ms (1.0×)** | 7,359.1 ms (18.3×) | — | 1,709.3 ms (4.3×) | 21.3 s (52.9×) | — | — |
| `regex-prefix-1` | String / REGEX | 170.5 ms | **6.72 ms** | — | 1,793.7 ms | 19.6 s | — | — |
| `regex-prefix-2` | String / REGEX | 27.0 ms | **3.96 ms** | — | 1,720.7 ms | 20.8 s | — | — |
| `regex-prefix-3` | String / REGEX | 10.3 ms | **1.76 ms** | — | 1,675.7 ms | 21.3 s | — | — |
| `strafter` | String / REGEX | **136.4 ms (1.0×)** | 10.9 s (80.1×) | — | 1,702.7 ms (12.5×) | 34.5 s (252.7×) | — | — |
| `strbefore` | String / REGEX | **120.7 ms (1.0×)** | 10.1 s (83.4×) | — | 1,568.5 ms (13.0×) | 11.9 s (98.6×) | — | — |
| `strends` | String / REGEX | **100.9 ms (1.0×)** | 6,720.6 ms (66.6×) | — | 1,557.6 ms (15.4×) | 2,919.0 ms (28.9×) | — | — |
| `strlen` | String / REGEX | **109.8 ms (1.0×)** | 7,098.8 ms (64.7×) | — | 1,628.9 ms (14.8×) | 5,654.7 ms (51.5×) | — | — |
| `strstarts` | String / REGEX | **54.5 ms (1.0×)** | 6,700.4 ms (123.0×) | — | 1,553.4 ms (28.5×) | 2,925.1 ms (53.7×) | — | — |
| `transitive-path-large-join-and-plus` | Transitive paths | **0.58 ms** | 682.0 ms | — | 136.8 ms | 2,897.1 ms | — | — |
| `transitive-path-plus` | Transitive paths | **0.59 ms** | 0.81 ms | 252.1 ms | — | 0.70 ms | — | — |
| `transitive-path-plus-fixed-subject` | Transitive paths | **0.60 ms** | 0.77 ms | 902.0 ms | 0.96 ms | 0.73 ms | — | — |
| `transitive-path-small-join-and-plus` | Transitive paths | 0.63 ms | 0.95 ms | 248.5 ms | 0.85 ms | **0.48 ms** | 4.60 ms | — |
| `result-size-large` | Result size / export | 658.1 ms (2.1×) | **310.3 ms (1.0×)** | 180.0 s (580.1×) | 17.1 s (55.0×) | 345.0 ms (1.1×) | 155.5 s (501.2×) | — |
| `result-size-medium` | Result size / export | 69.3 ms (2.0×) | 37.5 ms (1.1×) | 48.4 s (1392.8×) | 1,555.2 ms (44.7×) | **34.8 ms (1.0×)** | 6,032.8 ms (173.5×) | — |
| `result-size-small` | Result size / export | 7.37 ms | 2.20 ms | 488.0 ms | 5.25 ms | **0.76 ms** | 5.75 ms | — |
| `result-size-tiny` | Result size / export | 6.80 ms | 1.58 ms | 5.15 ms | 0.89 ms | **0.46 ms** | 4.12 ms | — |
| `result-size-xlarge` | Result size / export | 6,588.5 ms (2.1×) | **3,193.7 ms (1.0×)** | 180.0 s (56.4×) | 17.9 s (5.6×) | 3,472.0 ms (1.1×) | — | — |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 740.27 s | 0.758 M tr/s | 16.20 GiB (maximum process RSS) | 29.69 GB ledger directory | fluree create dblp --from dblp.nt; 561,477,456 distinct statements. Process wall time includes import completion and statistics; single import measurement. |
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
| Fluree | v4.2.0 (`603974fad5c13efed9d147d214d613849fb43c73`) | Official x86_64 Linux release binary, checksum verified. Fresh native import; default auto cache and Sync durability. Local HTTP TSV; no result cache. |
| QLever | git 621cf31 (native) (`621cf31 (native binaries from adfreiburg/qlever:latest image, run directly — no Docker)`) | native; MEMORY_FOR_QUERIES 26G, CACHE_MAX_SIZE 6G (disabled for the benchmark), in-memory-compressed vocab, TIMEOUT 300s — matches ad-freiburg/sparqloscope docs/Qleverfile.dblp |
| Oxigraph | 0.5.8 (native, prebuilt binary) (`oxigraph_v0.5.8_x86_64_linux_gnu (GitHub release)`) | serve-read-only; systemd MemoryMax 52G; no result cache; no server-side query timeout (issue #1336). Sweep methodology DEVIATES from the other engines: warmup 0 + 1 timed run, 180 s timeout, memory-capped with per-query restart-on-failure (mirrors ad-freiburg/sparqloscope util/oxigraph-helper.sh). RocksDB-backed. |
| Virtuoso | 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7) (`07.20.3229`) | 32 GB profile: NumberOfBuffers 2,720,000 (~21 GB), MaxDirtyBuffers 2,000,000, MaxQueryExecutionTime 300 s, ResultSetMaxRows 10M. Data in named graph <https://dblp.org>; queries sent with default-graph-uri. Ubuntu apt 07.20.3229 has a broken ld_dir; data loaded via chunked TTLP(file_to_string(chunk)) in parallel. |
| MillenniumDB | v1.0.0 (built from source) (`github.com/MillenniumDB/MillenniumDB main`) | native; versioned-buffer 22GB, strings-static 4GB, strings-dynamic 4GB; body POST; no result cache. Built on its own m7a.4xlarge (16c/64GB), dblp-core pulled from S3. |
| Jena | Apache Jena 6.1.0 / Fuseki 6.1.0 (JDK 21) (`6.1.0`) | TDB2 + Fuseki; JVM_ARGS -Xmx32g; body POST; no result cache. Fuseki started cold for benchmark run (no JVM warmup, no OS page cache warmup of 54GB index). |
| Blazegraph | 2.1.6-RC (Java 11) (`BLAZEGRAPH_2_1_6_RC`) | native jar; offline DataLoader on a SKOLEMIZED .nt (blank nodes rewritten to IRIs — required: default load silently drops ALL blank-node triples, 239M/561M); served with -Xmx16g; web.xml queryTimeout 180000; queries via --post-form. Dedicated m7a.4xlarge. |

**Caveats**
- Fluree measured 2026-09-07; other engines measured 2026-06-11. Dedicated hosts of the same instance class, not the same physical host. Absolute timings can vary between hosts.
- All engines use the pinned 2026-06-01 DBLP archive. This differs from the older snapshots used in the SPARQLoscope paper, so absolute timings are not directly comparable to that paper.
- Virtuoso uses chunked TTLP loading; its ld_dir loader was broken in the tested Ubuntu package.
- Jena starts with a cold JVM/TDB cache and a 54 GB index on a 64 GB host; its completion count is cache-state sensitive.
- Oxigraph uses no warmup and one measured request, with a 180 s timeout, a memory cap, and restart on failure. This differs from the other engines' warmup/median-of-three protocol.
- This comparison measures query completion and latency. It does not assert result equivalence across all engines. See the per-query table for differences in performance.
- [Reproduce the Fluree run](v420-release/REPORT.md): pinned binary, dataset and harness checksums, import and query commands.
