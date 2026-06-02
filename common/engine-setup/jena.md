# Apache Jena / Fuseki (native)

TDB2 store + Fuseki HTTP server. Needs Java 17+ (Jena 6.x).

## Install

```bash
sudo apt-get install -y openjdk-21-jdk-headless
cd ~/jena
for f in apache-jena-6.1.0 apache-jena-fuseki-6.1.0; do
  curl -sL -O "https://dlcdn.apache.org/jena/binaries/$f.tar.gz" && tar -xzf "$f.tar.gz"; done
```

## Index (tdb2.xloader)

```bash
# NB: --loc dir must NOT pre-exist (xloader creates it)
~/jena/apache-jena-6.1.0/bin/tdb2.xloader --loc ~/jena/tdb --tmpdir ~/jena/tmp ~/data/dblp.ttl
```

- xloader is the bulk loader (external sort on disk; needs ~data-sized temp space).
- **It is by far the slowest loader here:** phases are nodes (~20 min) → terms →
  data → build each permutation (SPO/POS/OSP) separately. DBLP-core: **~7,471 s
  (~124 min)**, 54 GB index. Low RAM (external sort), one brief load lull is normal.
- Feeds a **gzipped** file directly (`~/data/file.nt.gz`) — no need to decompress;
  Java reads multi-member gzip fine. `openjdk-21-jre-headless` is enough to run
  xloader + Fuseki (the `-jdk-` isn't required).
- At billions this is the bottleneck: 8 B truthy ≈ each phase scans 8 B, so expect
  **~12–30 h**. Point `--tmpdir` at the big disk (xloader temp ≈ data size).

## Serve + query

```bash
JVM_ARGS='-Xmx32g' ~/jena/apache-jena-fuseki-6.1.0/fuseki-server \
  --loc ~/jena/tdb --timeout=300000 /dblp        # :3030, query timeout 300 s
# endpoint: POST http://localhost:3030/dblp/sparql  (accepts application/sparql-query)
../../common/run_benchmark.sh --endpoint http://localhost:3030/dblp/sparql \
  -r 3 -w 1 -t 300 -o reports/<ds>/engines/jena.tsv
```

No COUNT fastpath and cold TDB2 page reads make queries slow on 561 M triples —
heavy queries hit the ~300 s budget. The runner's per-query 300 s budget (1 run for
a ~300 s query, not 3×) keeps the sweep tractable. No result cache to clear.
