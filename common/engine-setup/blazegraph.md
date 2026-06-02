# Blazegraph (native)

Single jar, Java. Blazegraph 2.1.6 is old → use **Java 11** (Java 17+ breaks it).

## Install + prepare data

```bash
# Java 11. NOTE: Ubuntu 24.04 (noble) dropped openjdk-11 from apt
# (`apt-cache policy openjdk-11-jre-headless` → Candidate: none). Fetch Temurin 11:
curl -sSL "https://api.adoptium.net/v3/binary/latest/11/ga/linux/x64/jdk/hotspot/normal/eclipse" \
  | tar xz -C ~/ && mv ~/jdk-11* ~/jdk11      # then use ~/jdk11/bin/java
#   (on older Ubuntu where it exists: sudo apt-get install -y openjdk-11-jdk-headless)
curl -sL -o ~/blazegraph.jar \
  https://github.com/blazegraph/database/releases/download/BLAZEGRAPH_2_1_6_RC/blazegraph.jar
# Blazegraph loads via SPARQL UPDATE LOAD; split the N-Triples into 1M-triple gz chunks:
mkdir ~/chunks
split -a 4 --numeric-suffixes=1 --additional-suffix=.nt -l 1000000 \
  --filter='gzip > $FILE.gz' ~/dblp.nt ~/chunks/dblp-      # -> ~561 chunks
```

(Our dump is already N-Triples; the paper's extra Turtle→N-Triples `riot` step is
not needed.)

## ⚠️ Loading DBLP: blank nodes will silently drop >half the data

DBLP is **blank-node-heavy** (every authorship "signature" is a labeled blank node,
`_:Sig_<hash>`, with several triples). Blazegraph's **default** blank-node handling
collapses these, so the load silently keeps only part of the graph — **no parse
errors, `failSet=0`, it just stores fewer triples**. On DBLP-core 2026-06-01 we got
**239 M of ~561 M** triples — *both* via chunked `LOAD` *and* via the default
`DataLoader`. So it is **not** a load-method bug; it's blank-node handling.

**`storeBlankNodes=true` does NOT fix it** (we confirmed it was set on the namespace
via `/namespace/kb/properties`, yet the load still dropped **every** triple touching
a blank node — `hasSignature` = 0, `signatureDblpName` = 0, `COUNT{?s ?p ?o
FILTER(isBlank(?s))}` = 0, while IRI/literal triples like `title` = 8.5 M were fine;
total stuck at exactly 239,412,597). The chunked `LOAD` and *both* DataLoader runs
(default and `storeBlankNodes=true`) gave the identical 239 M.

**The working fix: skolemize** — rewrite `_:label` blank nodes as real IRIs in the
`.nt` before loading (Blazegraph stores IRIs fine). DBLP's blank-node labels are
unique per entity, so skolem IRIs preserve the graph exactly, and because the
SPARQLoscope queries match *patterns* (`?s hasSignature ?sig . ?sig …`), results are
identical whether `?sig` is a blank node or a skolem IRI — so it stays comparable.
**Always verify `COUNT(*)` ≈ the other engines (~561.5 M) before sweeping.**

Two more traps on a 64 GB box:
- **Chunked `LOAD` (`split` → one `LOAD` per chunk) is the wrong tool here.** 575
  separate auto-committed transactions over a growing index **GC-thrash** (load 12+,
  queries timing out) and **decelerate** badly (5 s/chunk → 35 s/chunk → ~4.5 h),
  on top of the blank-node loss. Use the offline `DataLoader` instead.
- Don't discard `LOAD`/loader output — capture it so silent shortfalls are visible.

## Load (skolemize → offline DataLoader)

1. **Skolemize** the blank nodes to IRIs (one `sed` pass over the `.nt`):

```bash
sed -E 's@_:([A-Za-z0-9_]+)@<https://dblp.org/skbn/\1>@g' ~/dblp.nt > ~/dblp.skol.nt
# verify few/no blank nodes remain: grep -c '_:' ~/dblp.skol.nt   (DBLP leaves ~16,
# labels with chars outside [A-Za-z0-9_]; widen the class if you need them too)
```

2. **DataLoader** the skolemized file. `fastload.properties` (DiskRW, no
inference/text-index, big branchingFactor — `storeBlankNodes` is now irrelevant since
there are no blank nodes):

```ini
com.bigdata.journal.AbstractJournal.file=/home/ubuntu/blazegraph.jnl
com.bigdata.journal.AbstractJournal.bufferMode=DiskRW
com.bigdata.rdf.store.AbstractTripleStore.quads=false
com.bigdata.rdf.store.AbstractTripleStore.statementIdentifiers=false
com.bigdata.rdf.store.AbstractTripleStore.textIndex=false
com.bigdata.rdf.store.AbstractTripleStore.axiomsClass=com.bigdata.rdf.axioms.NoAxioms
com.bigdata.rdf.sail.truthMaintenance=false
com.bigdata.namespace.kb.spo.com.bigdata.btree.BTree.branchingFactor=1024
com.bigdata.namespace.kb.lex.com.bigdata.btree.BTree.branchingFactor=400
```

```bash
java -server -Xmx40g -cp ~/blazegraph.jar \
  com.bigdata.rdf.store.DataLoader -namespace kb ~/fastload.properties ~/dblp.skol.nt
# DataLoader prints "<N> stmts added ... rate=...". Loading the FULL ~561M (vs the
# broken 239M) takes proportionally longer — budget ~1.5-2 h, journal ~55-60 GB.
```

> **Gotchas that cost us time:** (1) `pkill -f blazegraph.jar` also kills a running
> DataLoader (same jar) — don't run it while loading; (2) don't start the server /
> verify until the loader prints its final `stmts added` (early checks read an
> uncommitted/empty journal → COUNT 0).

> **Wikidata / billions:** same DataLoader path; keep `-Xmx` modest (≈ 64 GB even on
> a 512 GB box) so the OS page cache holds the journal. Wikidata has out-of-range
> dates (e.g. `0000-08-13...`) that log a non-fatal XSD-parse ERROR (skipped). Near
> ~8 B Blazegraph is at its practical ceiling — expect very slow loads / non-completion.

## Serve

```bash
# web.xml: queryTimeout in ms (e.g. 180000 for the 180s spec)
java -server -Xmx32g -Dbigdata.propertyFile=$PWD/fastload.properties \
  -Djetty.overrideWebXml=$PWD/web.xml -jar ~/blazegraph.jar &
# MANDATORY before sweeping — must match the other engines (~561.5M), not 239M:
curl -s http://localhost:9999/blazegraph/namespace/kb/sparql \
  --data-urlencode 'query=SELECT (COUNT(*) AS ?c){?s ?p ?o}' -H 'Accept: text/tab-separated-values'
```

## Query

```bash
../../common/run_benchmark.sh \
  --endpoint http://localhost:9999/blazegraph/namespace/kb/sparql \
  -r 3 -w 1 -t 300 -o reports/<ds>/engines/blazegraph.tsv
```

Use `-t 180` (the spec) and `--post-form` (Blazegraph's `/sparql` was flaky with a
raw `application/sparql-query` body in our run; url-encoded `query=` is reliable).
Aggregate full-scan counts are weak on Blazegraph: the **official SPARQLoscope
DBLP Blazegraph run also returned HTTP 500 on `number-of-triples` /
`number-of-subjects`**, so timeouts/errors there are expected, not a setup mistake.

> **Status for DBLP-core (2026-06-01):** chunked `LOAD`, default DataLoader, and
> DataLoader+`storeBlankNodes=true` all loaded only 239,412,597 / ~561.5 M (every
> blank-node triple dropped). The **skolemize → DataLoader** path is the fix; record
> Blazegraph's import/index/pass numbers only once `COUNT(*)` ≈ 561.5 M and
> `hasSignature` > 0 are verified on the skolemized load.
