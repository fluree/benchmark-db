# Virtuoso (native)

OpenLink Virtuoso Open Source, from Ubuntu apt.

## Install + configure

```bash
sudo apt-get install -y virtuoso-opensource     # 7.2.5.1 on Ubuntu 24.04
sudo systemctl stop virtuoso-opensource-7
```

Edit `/etc/virtuoso-opensource-7/virtuoso.ini` for the 32 GB profile + our data
dir + SPARQL settings (then `sudo systemctl start virtuoso-opensource-7`):

```ini
[Parameters]
NumberOfBuffers = 2720000        ; ~21 GB (the recommended 32 GB-RAM value)
MaxDirtyBuffers = 2000000
DirsAllowed     = ., /usr/share/virtuoso-opensource-7/vad, /home/ubuntu/data
[SPARQL]
DefaultGraph          = https://dblp.org
ResultSetMaxRows      = 10000000     ; default 10000 would TRUNCATE result-size-* queries
MaxQueryExecutionTime = 300          ; seconds
```

isql: `isql-vt 1111 dba dba`.

> **Scale to the box.** `NumberOfBuffers` ≈ `85000 × RAM_GB` (≈ 66 % of RAM as 8 KB
> pages), `MaxDirtyBuffers` ≈ 0.75 of that. The 2.72 M above is the 32 GB profile;
> a 512 GB box wants ≈ **32 M / 24 M** (verified loading 8 B truthy). Raise
> `ServerThreads` (e.g. 200) so many parallel loaders have threads. Use a per-dataset
> graph IRI (`https://www.wikidata.org/` for truthy, not `https://dblp.org`) in both
> `DefaultGraph` and the load/query.

## Load (split + parallel)

Single-file `rdf_loader_run()` is slow; split into chunks and run parallel loaders
(or point `ld_dir` at an existing directory of `*.nt.gz` shards — `rdf_loader_run`
decompresses `.gz`, and more shards = more parallelism; use ≈ one loader per 2 cores):

```bash
cd /home/ubuntu/data
split -n l/16 -d -a 2 --additional-suffix=.nt dblp.nt part_     # 16 chunks
isql-vt 1111 dba dba <<'SQL'
ld_dir('/home/ubuntu/data', '*.nt', 'https://dblp.org');
SQL
for i in $(seq 1 8); do echo "rdf_loader_run();" | isql-vt 1111 dba dba & done; wait
echo "checkpoint;" | isql-vt 1111 dba dba
```

DBLP-core: 217 s split + 411 s parallel load = **628 s till-ready**, 17 GB,
561,483,067 triples, 90 predicates. (Verify with
`SELECT (COUNT(*) AS ?c) WHERE { GRAPH <https://dblp.org> {?s ?p ?o} }`.)

> **⚠ Wikidata gotcha — `geo:wktLiteral` aborts shards.** Virtuoso 7.10+ rejects
> Wikidata's globe-prefixed WKT coordinates with `RDFGE: RDF box with a geometry RDF
> type and a non-geometry content`, and the error **aborts the entire shard** (so a
> parallel load silently loses ~⅓ of the data — e.g. 8 B truthy loaded only 5.53 B,
> with 629/1444 shards in `load_list` showing `ll_error`). There is no INI flag to
> disable geometry validation ([openlink/virtuoso-opensource#295](https://github.com/openlink/virtuoso-opensource/issues/295)).
> Workaround: drop the `wktLiteral` triples from the input and re-load the failed shards:
> ```bash
> # errored files: SELECT ll_file FROM DB.DBA.load_list WHERE ll_error IS NOT NULL;
> zcat shard.nt.gz | grep -v wktLiteral | gzip > fixed_shard.nt.gz   # then ld_dir + rdf_loader_run
> # also: DELETE FROM DB.DBA.load_list WHERE ll_error IS NOT NULL;  before re-registering
> ```
> Always **verify the post-load count** against the other engines — a "successful"
> parallel load can be silently partial. Also seen: a few `SR197: Non unique primary
> key on RDF_LANGUAGE` errors from the parallel loaders racing on new language tags —
> fewer loaders (or a re-load, once the tags exist) clears them.

## Query — needs form-POST + default-graph

Virtuoso's `/sparql` does **not** accept a raw `application/sparql-query` body, and
a no-FROM query unions its system graphs (virtrdf#, owl#, …). So query with
url-encoded `query=` **and** `default-graph-uri` so only dblp is hit:

```bash
../../common/run_benchmark.sh --endpoint "http://localhost:8890/sparql" \
  --post-form --default-graph "https://dblp.org" \
  -r 3 -w 1 -t 180 -o reports/<ds>/engines/virtuoso.tsv     # DBLP-core: 180 s; billion-scale: 300 s
```

No result cache to clear (warm buffers, like Fluree). No COUNT fastpath:
`number-of-objects`/`number-of-subjects` time out; `transitive-path-plus` returns
HTTP 500. 102/105 completed.
