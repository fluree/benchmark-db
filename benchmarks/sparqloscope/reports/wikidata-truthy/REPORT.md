# SPARQLoscope benchmark — Wikidata Truthy

> **8.19B-triple 2026-05-29 truthy snapshot on r7a.16xlarge (64c/512GB/3TB). Four engines: Fluree 94/105, QLever latest 91/105, Virtuoso 7.2.5.1 80/105 (loaded 8.17B, geo:wktLiteral dropped), MillenniumDB v1.0.0 63/105 (loaded full 8.18B). Jena EXCLUDED (TDB2 xloader did not finish loading 8.19B within the run window). Blazegraph EXCLUDED (drops blank nodes even with storeBlankNodes=true + scale ceiling). 105 queries, 1 warmup + 3 runs, 300s timeout (early-abort). Fluree ran the v4.0.5 pre-release count-fastpath build (reports 4.0.4); queries are COUNT-dominated. Engine-vs-engine on this box only.**

**Dataset:** 8,186,371,175 triples, 13,306 predicates (snapshot 2026-05-29 11:17:24 GMT (rolling latest; pinned as GitHub release wikidata-truthy-source-20260529). Paper used 'as of 2025-04-18', no longer on the live mirror.) · **Engines:** Fluree 4.0.4, QLever latest, Virtuoso 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7), MillenniumDB v1.0.0 · **Box:** AWS r7a.16xlarge (64c / 512 GB) · 1+3 runs, median, 300 s timeout

_Query results first; dataset/hardware/import detail in §3–§4._

## 1. Query benchmark

### 1a. Aggregates

| metric | Fluree | QLever | Virtuoso | MillenniumDB |
|---|---|---|---|---|
| passed | 94/105 | 91/105 | 80/105 | 63/105 |
| arith mean | **4,302 ms (1.0×)** | 18.0 s (4.2×) | 57.6 s (13.4×) | 55.5 s (12.9×) |
| geo mean | **994 ms (1.0×)** | 1,690 ms (1.7×) | 6,294 ms (6.3×) | 3,896 ms (3.9×) |
| median | **978 ms (1.0×)** | 2,730 ms (2.8×) | 15.7 s (16.1×) | 4,211 ms (4.3×) |

**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):

| Fluree | QLever | Virtuoso | MillenniumDB |
|---|---|---|---|
| 1.47× | 5.28× | 13.16× | 11.58× |

### 1b. By category (geo mean)

| category | n | Fluree | QLever | Virtuoso | MillenniumDB | fastest |
|---|--:|---|---|---|---|---|
| Dataset statistics | 6 | 528 ms (45.3×) | **12 ms (1.0×)** | 2,561 ms (219.9×) | 206.5 s (17736.4×) | QLever |
| JOIN | 12 | 900 ms (38.4×) | 2,624 ms (112.0×) | 2,387 ms (101.9×) | **23 ms (1.0×)** | MillenniumDB |
| OPTIONAL | 10 | **1,175 ms (1.0×)** | 10.7 s (9.1×) | 7,029 ms (6.0×) | 10.6 s (9.0×) | Fluree |
| MINUS | 10 | **1,180 ms (1.0×)** | 10.0 s (8.5×) | 5,187 ms (4.4×) | 13.7 s (11.6×) | Fluree |
| EXISTS | 10 | 1,174 ms (1.7×) | 16.4 s (24.3×) | 1,371 ms (2.0×) | **675 ms (1.0×)** | MillenniumDB |
| UNION | 5 | **1,381 ms (1.0×)** | 9,589 ms (6.9×) | 19.6 s (14.2×) | 106.9 s (77.4×) | Fluree |
| GROUP BY / aggregate | 16 | 968 ms (1.2×) | **812 ms (1.0×)** | 4,778 ms (5.9×) | 4,673 ms (5.8×) | QLever |
| FILTER | 3 | 2,409 ms (1.7×) | **1,380 ms (1.0×)** | 50.0 s (36.2×) | 107.9 s (78.2×) | QLever |
| Numeric functions | 10 | **651 ms (1.0×)** | 1,335 ms (2.0×) | 5,994 ms (9.2×) | 4,007 ms (6.2×) | Fluree |
| Date functions | 3 | 3,977 ms (2.0×) | 3,389 ms (1.7×) | **1,991 ms (1.0×)** | 3,888 ms (2.0×) | Virtuoso |
| String / REGEX | 11 | 1,640 ms (31.2×) | **53 ms (1.0×)** | 251.4 s (4787.1×) | 244.5 s (4655.8×) | QLever |
| Transitive paths | 4 | 584 ms (6.8×) | **85 ms (1.0×)** | — | 335 ms (3.9×) | QLever |
| Result size / export | 5 | 457 ms (5.0×) | 444 ms (4.8×) | 248 ms (2.7×) | **92 ms (1.0×)** | MillenniumDB |

### 1c. Per query

| query | category | Fluree | QLever | Virtuoso | MillenniumDB |
|---|---|---|---|---|---|
| `number-of-blank-nodes` | Dataset statistics | 92 ms | 16 ms | **8 ms** | 177.5 s |
| `number-of-literals` | Dataset statistics | **11.7 s (1.0×)** | 155.9 s (13.4×) | 88.2 s (7.6×) | 248.7 s (21.3×) |
| `number-of-objects` | Dataset statistics | 1,697 ms | **1 ms** | — | — |
| `number-of-predicates` | Dataset statistics | 92 ms | **1 ms** | — | — |
| `number-of-subjects` | Dataset statistics | 1,403 ms | **1 ms** | — | — |
| `number-of-triples` | Dataset statistics | 92 ms | **1 ms** | 23.8 s | 199.6 s |
| `join-2-large-large` | JOIN | **1,001 ms (1.0×)** | 27.5 s (27.5×) | 232.7 s (232.5×) | — |
| `join-2-large-large-with-large-result` | JOIN | **837 ms (1.0×)** | 13.2 s (15.7×) | 155.0 s (185.2×) | — |
| `join-2-large-large-with-small-result` | JOIN | **215 ms (1.0×)** | 550 ms (2.6×) | 1,211 ms (5.6×) | 7,663 ms (35.6×) |
| `join-2-large-small` | JOIN | 155 ms | 53 ms | **5 ms** | 8 ms |
| `join-2-largest-result` | JOIN | **600 ms (1.0×)** | 15.8 s (26.3×) | — | — |
| `join-2-small-large` | JOIN | 154 ms | 51 ms | **5 ms** | 15 ms |
| `join-3-chain-largest-sum-of-join-sizes` | JOIN | 26.8 s (1.4×) | **18.5 s (1.0×)** | 107.4 s (5.8×) | — |
| `join-3-star-largest-sum-of-join-sizes` | JOIN | **2,792 ms (1.0×)** | 22.9 s (8.2×) | 55.1 s (19.7×) | — |
| `join-xlarge-chain-on-small-predicates` | JOIN | 134 ms | 856 ms | 58 ms | **1 ms** |
| `join-xlarge-star-on-small-predicates` | JOIN | 140 ms | 85 ms | 369 ms | **1 ms** |
| `multicolumn-join-large` | JOIN | **20.9 s (1.0×)** | 111.0 s (5.3×) | 43.7 s (2.1×) | — |
| `multicolumn-join-small` | JOIN | 3,713 ms (20.6×) | 3,661 ms (20.3×) | 2,375 ms (13.2×) | **180 ms (1.0×)** |
| `optional-join-2-large-large-with-large-result` | OPTIONAL | **862 ms (1.0×)** | 63.1 s (73.1×) | — | — |
| `optional-join-2-large-large-with-small-join-result-1` | OPTIONAL | **301 ms (1.0×)** | 1,668 ms (5.5×) | 25.5 s (84.6×) | 72.1 s (239.4×) |
| `optional-join-2-large-large-with-small-join-result-2` | OPTIONAL | **215 ms (1.0×)** | 1,631 ms (7.6×) | 1,434 ms (6.7×) | 72.9 s (339.0×) |
| `optional-join-3-chain-1` | OPTIONAL | 27.4 s (1.4×) | **19.5 s (1.0×)** | 124.5 s (6.4×) | — |
| `optional-join-3-chain-2` | OPTIONAL | **25.0 s (1.0×)** | — | — | — |
| `optional-join-3-star-1` | OPTIONAL | **2,750 ms (1.0×)** | 121.9 s (44.3×) | — | — |
| `optional-join-3-star-2` | OPTIONAL | **2,247 ms (1.0×)** | 58.7 s (26.1×) | 93.7 s (41.7×) | 200.4 s (89.2×) |
| `optional-join-large-large` | OPTIONAL | **1,030 ms (1.0×)** | 78.1 s (75.9×) | — | — |
| `optional-join-large-small` | OPTIONAL | **130 ms (1.0×)** | 18.8 s (144.9×) | 47.1 s (362.6×) | — |
| `optional-join-small-large` | OPTIONAL | 158 ms | 53 ms | **6 ms** | 12 ms |
| `minus-join-2-large-large-with-large-result` | MINUS | **785 ms (1.0×)** | 26.8 s (34.1×) | — | — |
| `minus-join-2-large-large-with-small-join-result-1` | MINUS | **181 ms (1.0×)** | 581 ms (3.2×) | 25.7 s (141.9×) | 74.5 s (411.7×) |
| `minus-join-2-large-large-with-small-join-result-2` | MINUS | **184 ms (1.0×)** | 699 ms (3.8×) | 1,375 ms (7.5×) | 72.9 s (396.4×) |
| `minus-join-3-chain-1` | MINUS | 20.1 s (1.3×) | **15.3 s (1.0×)** | 57.2 s (3.7×) | 108.7 s (7.1×) |
| `minus-join-3-chain-2` | MINUS | **23.6 s (1.0×)** | — | — | — |
| `minus-join-3-star-1` | MINUS | **12.7 s (1.0×)** | 85.8 s (6.8×) | — | — |
| `minus-join-3-star-2` | MINUS | **1,580 ms (1.0×)** | 62.4 s (39.5×) | 34.3 s (21.7×) | 118.4 s (74.9×) |
| `minus-join-large-large` | MINUS | **884 ms (1.0×)** | 25.8 s (29.2×) | — | — |
| `minus-join-large-small` | MINUS | **154 ms (1.0×)** | 27.3 s (177.5×) | 46.9 s (304.6×) | — |
| `minus-join-small-large` | MINUS | 155 ms | 1,596 ms | **6 ms** | 7 ms |
| `exists-join-2-large-large-with-large-result` | EXISTS | **779 ms (1.0×)** | 46.5 s (59.7×) | — | — |
| `exists-join-2-large-large-with-small-join-result-1` | EXISTS | **178 ms (1.0×)** | 1,077 ms (6.1×) | 71.9 s (404.2×) | — |
| `exists-join-2-large-large-with-small-join-result-2` | EXISTS | **185 ms (1.0×)** | 937 ms (5.1×) | 1,362 ms (7.4×) | — |
| `exists-join-3-chain-1` | EXISTS | **20.0 s (1.0×)** | 27.2 s (1.4×) | 68.4 s (3.4×) | 114.1 s (5.7×) |
| `exists-join-3-chain-2` | EXISTS | **23.7 s (1.0×)** | — | — | — |
| `exists-join-3-star-1` | EXISTS | **12.5 s (1.0×)** | 25.8 s (2.1×) | — | — |
| `exists-join-3-star-2` | EXISTS | **1,510 ms (1.0×)** | 95.2 s (63.1×) | 33.1 s (21.9×) | — |
| `exists-join-large-large` | EXISTS | **918 ms (1.0×)** | 62.0 s (67.6×) | — | — |
| `exists-join-large-small` | EXISTS | 154 ms | 27.2 s | **6 ms** | — |
| `exists-join-small-large` | EXISTS | 154 ms | 16.3 s | 5 ms | **4 ms** |
| `union-constraint-filter-restrictive` | UNION | 29.2 s (6.8×) | 33.1 s (7.7×) | **4,300 ms (1.0×)** | 106.3 s (24.7×) |
| `union-constraint-from-star` | UNION | **2,427 ms (1.0×)** | 20.3 s (8.4×) | 59.0 s (24.3×) | 196.3 s (80.9×) |
| `union-constraint-large-join` | UNION | **1,049 ms (1.0×)** | 16.6 s (15.8×) | 183.6 s (175.0×) | 208.6 s (198.9×) |
| `union-constraint-small-join` | UNION | **505 ms (1.0×)** | 3,026 ms (6.0×) | 3,485 ms (6.9×) | 29.0 s (57.5×) |
| `union-no-constraint` | UNION | **134 ms (1.0×)** | 2,406 ms (18.0×) | 17.6 s (131.6×) | 110.3 s (823.0×) |
| `distinct-count-object-high-multiplicity` | GROUP BY / aggregate | 133 ms (4.9×) | **27 ms (1.0×)** | 98 ms (3.6×) | 37 ms (1.4×) |
| `distinct-count-object-low-multiplicity` | GROUP BY / aggregate | — | — | — | — |
| `distinct-count-object-wrong-sort-order` | GROUP BY / aggregate | 19.5 s (2.6×) | **7,561 ms (1.0×)** | 10.4 s (1.4×) | 12.8 s (1.7×) |
| `group-by-complex-aggregate` | GROUP BY / aggregate | 18.1 s (1.6×) | **11.6 s (1.0×)** | 89.4 s (7.7×) | — |
| `group-by-count-object-high-multiplicity` | GROUP BY / aggregate | 126 ms | **2 ms** | 14 ms | 33 ms |
| `group-by-count-object-low-multiplicity` | GROUP BY / aggregate | **4,007 ms (1.0×)** | 52.8 s (13.2×) | — | — |
| `group-by-count-object-wrong-sort-order` | GROUP BY / aggregate | 18.0 s (12.8×) | 9,903 ms (7.0×) | **1,406 ms (1.0×)** | 11.9 s (8.5×) |
| `group-by-implicit-numeric-avg` | GROUP BY / aggregate | 2,047 ms (1.7×) | **1,202 ms (1.0×)** | 22.1 s (18.4×) | 3,659 ms (3.0×) |
| `group-by-implicit-numeric-baseline` | GROUP BY / aggregate | 125 ms | **2 ms** | 1,170 ms | 3,258 ms |
| `group-by-implicit-numeric-max` | GROUP BY / aggregate | **164 ms (1.0×)** | 1,107 ms (6.8×) | 11.2 s (68.4×) | 3,705 ms (22.6×) |
| `group-by-implicit-numeric-min` | GROUP BY / aggregate | **162 ms (1.0×)** | 1,127 ms (7.0×) | 6,649 ms (41.0×) | 3,775 ms (23.3×) |
| `group-by-implicit-numeric-sum` | GROUP BY / aggregate | 1,809 ms (1.5×) | **1,202 ms (1.0×)** | 13.9 s (11.5×) | 3,645 ms (3.0×) |
| `group-by-implicit-string-baseline` | GROUP BY / aggregate | 129 ms | **7 ms** | 7,947 ms | 88.4 s |
| `group-by-implicit-string-max` | GROUP BY / aggregate | — | **29.5 s (1.0×)** | 50.0 s (1.7×) | 102.9 s (3.5×) |
| `group-by-implicit-string-min` | GROUP BY / aggregate | — | **29.5 s (1.0×)** | 35.6 s (1.2×) | 105.7 s (3.6×) |
| `group-by-string-groupconcat` | GROUP BY / aggregate | — | — | — | — |
| `filter-few-results` | FILTER | **1,941 ms (1.0×)** | 27.3 s (14.1×) | 65.0 s (33.5×) | 87.4 s (45.0×) |
| `filter-language-en` | FILTER | 3,595 ms | **2 ms** | — | — |
| `filter-many-results` | FILTER | **2,003 ms (1.0×)** | 48.1 s (24.0×) | 38.4 s (19.2×) | 133.1 s (66.5×) |
| `numeric-abs` | Numeric functions | **1,856 ms (1.0×)** | 2,719 ms (1.5×) | 19.8 s (10.6×) | 4,188 ms (2.3×) |
| `numeric-add` | Numeric functions | **1,821 ms (1.0×)** | 3,770 ms (2.1×) | 6,835 ms (3.8×) | 4,561 ms (2.5×) |
| `numeric-baseline` | Numeric functions | 1,819 ms (1.5×) | **1,201 ms (1.0×)** | 13.8 s (11.5×) | 3,636 ms (3.0×) |
| `numeric-ceil` | Numeric functions | **1,854 ms (1.0×)** | 2,722 ms (1.5×) | 7,930 ms (4.3×) | 4,149 ms (2.2×) |
| `numeric-filter-bin-search-fifty-fifty` | Numeric functions | **140 ms (1.0×)** | 423 ms (3.0×) | 2,671 ms (19.1×) | 4,211 ms (30.1×) |
| `numeric-filter-bin-search-ninetyfive-five` | Numeric functions | **136 ms (1.0×)** | 275 ms (2.0×) | 2,227 ms (16.4×) | 3,875 ms (28.5×) |
| `numeric-filter-bin-search-seventy-thirty` | Numeric functions | **137 ms (1.0×)** | 358 ms (2.6×) | 2,405 ms (17.6×) | 4,045 ms (29.5×) |
| `numeric-floor` | Numeric functions | **1,854 ms (1.0×)** | 2,723 ms (1.5×) | 7,932 ms (4.3×) | 4,196 ms (2.3×) |
| `numeric-greater` | Numeric functions | **134 ms (1.0×)** | 1,735 ms (12.9×) | 4,495 ms (33.5×) | 3,120 ms (23.3×) |
| `numeric-round` | Numeric functions | **1,855 ms (1.0×)** | 2,721 ms (1.5×) | 7,929 ms (4.3×) | 4,282 ms (2.3×) |
| `date-day` | Date functions | 3,934 ms (2.0×) | 3,728 ms (1.9×) | **2,013 ms (1.0×)** | 3,866 ms (1.9×) |
| `date-month` | Date functions | 3,953 ms (2.0×) | 3,730 ms (1.9×) | **2,010 ms (1.0×)** | 3,867 ms (1.9×) |
| `date-year` | Date functions | 4,045 ms (2.1×) | 2,798 ms (1.4×) | **1,951 ms (1.0×)** | 3,932 ms (2.0×) |
| `regex-3` | String / REGEX | — | — | — | — |
| `regex-3-contains` | String / REGEX | — | — | **232.7 s (1.0×)** | 245.4 s (1.1×) |
| `regex-3-fixed` | String / REGEX | — | — | **261.9 s (1.0×)** | — |
| `regex-prefix-1` | String / REGEX | 3,846 ms (17.1×) | **225 ms (1.0×)** | 257.3 s (1143.7×) | — |
| `regex-prefix-2` | String / REGEX | 1,080 ms (23.5×) | **46 ms (1.0×)** | 258.9 s (5628.5×) | — |
| `regex-prefix-3` | String / REGEX | 761 ms (54.4×) | **14 ms (1.0×)** | 256.9 s (18347.0×) | — |
| `strafter` | String / REGEX | — | — | **282.2 s (1.0×)** | — |
| `strbefore` | String / REGEX | — | — | **270.3 s (1.0×)** | — |
| `strends` | String / REGEX | — | — | **230.3 s (1.0×)** | 246.7 s (1.1×) |
| `strlen` | String / REGEX | — | — | **235.5 s (1.0×)** | — |
| `strstarts` | String / REGEX | **2,287 ms (1.0×)** | — | 234.1 s (102.4×) | 241.6 s (105.6×) |
| `transitive-path-large-join-and-plus` | Transitive paths | **954 ms (1.0×)** | — | — | — |
| `transitive-path-plus` | Transitive paths | 6,354 ms (1.9×) | **3,308 ms (1.0×)** | — | 12.3 s (3.7×) |
| `transitive-path-plus-fixed-subject` | Transitive paths | 136 ms | **4 ms** | — | 19 ms |
| `transitive-path-small-join-and-plus` | Transitive paths | 141 ms (3.0×) | **47 ms (1.0×)** | — | 161 ms (3.4×) |
| `result-size-large` | Result size / export | **801 ms (1.0×)** | 2,730 ms (3.4×) | 19.8 s (24.7×) | 1,388 ms (1.7×) |
| `result-size-medium` | Result size / export | 234 ms (1.6×) | 375 ms (2.5×) | 575 ms (3.8×) | **150 ms (1.0×)** |
| `result-size-small` | Result size / export | 136 ms | 28 ms | 4 ms | **2 ms** |
| `result-size-tiny` | Result size / export | 134 ms | 23 ms | **0 ms** | **0 ms** |
| `result-size-xlarge` | Result size / export | **5,844 ms (1.0×)** | 26.2 s (4.5×) | 20.7 s (3.5×) | 15.6 s (2.7×) |

## 2. Result correctness

_No correctness check available for this run._

## 3. Import / indexing

| engine | import time | throughput | peak RAM | index size | notes |
|---|---|---|---|---|---|
| Fluree | 4,079 s (1:08:02) | 2.01 M flakes/s | 179 GB | 201 GB | 8,186.4M flakes across 1444 commits. Imported from a directory of 1444 single-member gzip shards (<768 MB each) as a workaround: Fluree's streaming chunker fails on uncompressed and on the 70 GB multi-member gzip for this high-prefix-cardinality data (see import bug report). |
| QLever | 8,653 s (2:24:13) | 0.95 M triples/s | n/a (mmap index) | 180 GB | Parallel-parsed the single N-Triples stream (no @prefix) at ~2.8M/s from pigz -dc. QLever indexed 8,180,599,054 triples (Fluree 8,186,371,175; +0.07% delta — QLever dedups exact-duplicate triples). First attempt failed merging 816 partial vocabularies on the default 1024 fd limit inside Docker; fixed with --ulimit nofile=1048576 and re-ran. |
| Virtuoso | ~108 min (40 min initial + 68 min geo-fix reload) | n/a | n/a | 367 GB (virtuoso.db; 434 GB db dir) | Loaded 8,174,845,462 triples. 629/1444 shards initially aborted on Wikidata geo:wktLiteral (RDFGE error; no INI flag to disable; known Virtuoso issue), fixed by filtering wktLiteral from the failed shards and reloading -> drops ~11.5M geo-coordinate triples (99.86% of dataset). 4 shards hit an RDF_LANGUAGE primary-key race on parallel load. |
| MillenniumDB | 5.05 h (18,193 s) | 0.45 M triples/s | n/a | 327 GB | Imported 8,180,602,084 triples (matches QLever's 8.18B exactly -- cleanest full load of the non-Fluree/QLever engines, no data loss). Server buffer total must stay below available RAM (288GB total failed to allocate right after the import). |

- **Fluree phases:** parse+commit ~35 cores to ~49 GB storage, then single-threaded index sort/merge buffering to ~179 GB RAM, then flush to 201 GB index

- **QLever phases:** parse ~48min, then convert-to-global-ids + 6-permutation sort/build

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
| Fluree | 4.0.4 (`ba88283 (feature/count-plan-aggregate-fastpaths)`) | server cache auto (~252 GB / 50% RAM); inline-indexed ledger; ulimit -n raised to 1048576 for the import |
| QLever | latest (`b802870 (adfreiburg/qlever:latest)`) | index -m 300G, num-triples-per-batch 10M, vocab on-disk-compressed; server MEMORY_FOR_QUERIES 200G, result cache disabled+cleared per query; docker --ulimit nofile=1048576 (required for vocab merge) |
| Virtuoso | 7.2.5.1 (Ubuntu apt, virtuoso-opensource-7) (`07.20.3229`) | NumberOfBuffers 32M / MaxDirtyBuffers 24M (~256GB), ServerThreads 200, MaxQueryExecutionTime 300s, ResultSetMaxRows 10M. Loaded via ld_dir of 1444 single-member .nt.gz shards into graph <https://www.wikidata.org/>, 32 parallel rdf_loader_run. Queries: form-POST (url-encoded query=) + default-graph-uri. No result cache (warm buffers, like Fluree). |
| MillenniumDB | v1.0.0 (`6118e08 (built from source)`) | cmake Release build (deps: libboost-all-dev, libicu-dev, libncurses-dev, libssl-dev). Import: pigz -dc | mdb import --format ttl --buffer-strings 100GB --buffer-tensors 100GB. Server: --versioned-buffer 120GB, strings 15/10GB, tensors 5/5GB, --threads 64 --timeout 300. Endpoint :1234/sparql (body POST). No result cache. |

**Caveats**
- Wikidata Truthy is the second dataset with a published SPARQLoscope reference (alongside DBLP).
- NOT comparable to the published SPARQLoscope table / paper: that used the 2025-04-18 truthy snapshot (~7.94B, gone from the live mirror); this is the current 2026-05-29 snapshot (~8.19B). Engine-vs-engine on this box is valid; absolute per-query COUNTs will not match the paper's reference yaml.
- Fluree was built from the COUNT-optimized count-plan-aggregate-fastpaths branch (ba88283), and the SPARQLoscope queries are COUNT-dominated — weigh Fluree's aggregate lead accordingly.
- QLever result cache disabled + cleared per query (re-executes each run) to match Fluree's no-result-cache behavior; stricter than the paper's run-once-with-warm-cache protocol.
- Triple-count delta: Fluree 8,186,371,175 vs QLever 8,180,599,054 (+0.07%) — different exact-duplicate handling on import (QLever dedups exact-duplicate triples). Both agree exactly on 13,306 predicates and 250,814,143 subjects; distinct-object counts differ (Fluree 1,660,872,132 vs QLever 1,671,827,330, ~0.66%) — literal-normalization difference.
- Both engines required a raised open-file limit (nofile 1048576) to index 8B triples: Fluree's import and QLever's vocabulary merge each hit the default 1024 fd limit (Fluree natively; QLever inside Docker via --ulimit).
- Result-equivalence (per-query correctness): a 60s spot-check shows count queries mostly agree exactly between engines (e.g. exists-join-2-large-large-with-large-result = 1,702,521,603 both); join-family queries (exists/minus/optional with small results) diverge ~0.2-0.7%, tracking the triple-count delta plus OPTIONAL/blank-node semantics. (Full multi-row result-equivalence diffing is out of scope for this run.)
- Virtuoso loaded 8,174,845,462 triples (~11.5M fewer than the others): Wikidata's geo:wktLiteral coordinates trigger Virtuoso's RDFGE error which aborts the whole shard, and the documented workaround drops those geo-coordinate triples (see common/engine-setup/virtuoso.md). Virtuoso also returns HTTP 500 on transitive-path-plus and times out on number-of-objects/subjects (no COUNT fastpath) -- expected (also in the published SPARQLoscope DBLP Virtuoso run); 80/105 passed.
- MillenniumDB loaded the full 8,180,602,084 triples (matches QLever exactly). 63/105 passed, 42 timeouts (no HTTP errors) -- slowest of the loaded engines on the heavy COUNT/join/string categories, but a clean complete load.
