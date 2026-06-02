# QLever (native)

QLever is run **natively** (no Docker — matches the SPARQLoscope paper). The
upstream binaries are the easiest source: pull them out of the official image
(they're Ubuntu 24.04 / glibc 2.39, same as our host) and run directly.

## Install (native binaries from the image)

```bash
sudo apt-get install -y docker.io      # only to extract the binaries
cid=$(docker create adfreiburg/qlever:latest)
sudo docker cp "$cid":/qlever/qlever-index /usr/local/bin/qlever-index
sudo docker cp "$cid":/qlever/qlever-server /usr/local/bin/qlever-server
docker rm "$cid"; sudo chmod +x /usr/local/bin/qlever-*
# runtime libs the binaries link against:
sudo apt-get install -y libjemalloc2 libboost-program-options1.83.0 \
                        libboost-iostreams1.83.0 libboost-url1.83.0
qlever-server --version   # git 621cf31 (DBLP-core run)
# control tool:
python3 -m venv ~/qlever-venv && ~/qlever-venv/bin/pip install qlever
```

## Index

The DBLP-core dump is a single N-Triples file → a **plain `qlever index` works**
(parallel parsing is fine; no `--parallel-parsing false` and no per-shard prefix
hacks the KG tar needed). Use this `Qleverfile` (matches `docs/Qleverfile.dblp`):

```ini
[data]
NAME = dblp
[index]
INPUT_FILES     = dblp.nt
CAT_INPUT_FILES = zcat ${INPUT_FILES}      # or `cat` for the decompressed .nt
SETTINGS_JSON   = { "num-triples-per-batch": 1000000, "group-by-hash-map-enabled": true }
VOCABULARY_TYPE = in-memory-compressed
STXXL_MEMORY    = 20G
[server]
PORT = 7015
ACCESS_TOKEN = dblp_token
MEMORY_FOR_QUERIES = 26G
CACHE_MAX_SIZE = 6G
TIMEOUT = 300s
[runtime]
SYSTEM = native
```

```bash
cd ~/qlever && cp <repo>/.../datasets/dblp-core/Qleverfile . && ln ~/data/dblp.nt.gz dblp.nt.gz
ulimit -n 1048576          # REQUIRED: 561M triples → ~533 partial vocabs to merge
~/qlever-venv/bin/qlever index
```

Two things Docker masked that bite a **native** run on 561M triples (both in the
Qleverfile/command above):
1. **`ulimit -n`** — default 1024 is too low for the vocab merge → *"Too many open
   files"*. Raise to 1048576 before `qlever index`.
2. **`STXXL_MEMORY`** — default is too small for the permutation merge →
   *"Insufficient memory for merging N blocks"*. 20 GB is ample on a 64 GB box.

DBLP-core: parse 2.3 M/s, total **521 s**, **9.4 GB** index, peak RSS 20.7 GB,
561,477,456 distinct triples.

## Serve + query

```bash
cd ~/qlever && ~/qlever-venv/bin/qlever start      # qlever-server on :7015
~/qlever-venv/bin/qlever settings group-by-hash-map-enabled=true
# disable + clear the result cache so each run re-executes (matches Fluree):
TOK=dblp_token
for p in cache-max-num-entries=0 cache-max-size=0B cache-max-size-single-entry=0B cache-max-size-lazy-result=0B; do
  curl -s -o /dev/null "http://localhost:7015/?access-token=$TOK&$p"; done
../../common/run_benchmark.sh --endpoint http://localhost:7015 \
  --clear-url "http://localhost:7015/?access-token=$TOK&cmd=clear-cache" \
  -r 3 -w 1 -t 300 -o reports/<ds>/engines/qlever.tsv
```

QLever caches full query results, so without the cache-disable + `--clear-url` the
timed runs would be ~1 ms cache hits. QLever answers dataset-statistics counts from
precomputed metadata (~0 ms) — it leads that category.
