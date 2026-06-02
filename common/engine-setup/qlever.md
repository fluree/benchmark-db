# Reproducing the benchmark on QLever

This runs the same 105 SPARQLoscope queries against **QLever** on the same DBLP
"KG with associated data" dataset, so QLever and Fluree numbers are directly
comparable on one machine. Tested with `adfreiburg/qlever:latest` via Docker.

> Two gotchas make plain `qlever index` fail on this dataset. They're handled
> below — read the **Index** step.

## 0. Prerequisites

```bash
sudo apt-get install -y docker.io
python3 -m venv ~/qlever-venv && ~/qlever-venv/bin/pip install qlever
sudo docker pull docker.io/adfreiburg/qlever:latest
```

## 1. Get the data

```bash
mkdir -p ~/qlever && cd ~/qlever
cp <repo>/benchmarks/sparqloscope/datasets/dblp-kg/Qleverfile ./Qleverfile
curl -LRC - -o dblp_KG_with_associated_data.tar \
  https://sparql.dblp.org/download/dblp_KG_with_associated_data.tar
tar -xf dblp_KG_with_associated_data.tar        # → 168 *.ttl.gz shards
```

Pin the same snapshot the engine under test loaded — see the dataset's
`DATASET.md` (e.g. `benchmarks/sparqloscope/datasets/dblp-kg/DATASET.md`) for the
source URL + SHA-256.

## 2. Index  ← the part that isn't "just `qlever index`"

The tar is a concatenation of Turtle shards, **each with its own `@prefix`
block**, and it's large. That breaks two QLever defaults:

1. **Parallel parser rejects mid-stream `@prefix`** → use `--parallel-parsing false`.
2. **Default sort/merge memory is too small** for ~1.5 B triples (504 merge
   blocks) → raise it with `-m` (we used `-m 90G` on a 128 GB box).

`qlever index` doesn't expose those flags, so run the index builder directly
(this is exactly what `qlever index` does under the hood, plus the two flags):

```bash
cd ~/qlever
echo '{ "num-triples-per-batch": 5000000, "group-by-hash-map-enabled": true }' > dblp.settings.json
docker run --rm -u $(id -u):$(id -g) \
  --mount type=bind,src="$(pwd)",target=/index -w /index \
  --name qlever.index.dblp --init --entrypoint bash \
  docker.io/adfreiburg/qlever:latest -c \
  '( echo "@base <https://dblp.org/rdf/schema> ."; zcat *.gz ) | \
   qlever-index -i dblp -s dblp.settings.json --vocabulary-type on-disk-compressed \
   -F ttl -f - --parallel-parsing false -m 90G 2>&1 | tee dblp.index-log.txt'
```

On a 16-core / 128 GB box this took ~65 min (sequential parse is the slow part)
and produced a ~20.7 GB index.

## 3. Start the server

```bash
cd ~/qlever && ~/qlever-venv/bin/qlever start    # serves SPARQL on :7015
```

## 4. Run the benchmark (fair, cache-cleared)

QLever caches full query results, so without intervention the timed runs would
be ~1 ms cache hits instead of real execution. Disable the cache and clear it
before each query, so QLever re-executes on warm index pages — matching Fluree
(which has no result cache):

```bash
TOK=dblp_token
for p in cache-max-num-entries=0 cache-max-size=0B cache-max-size-single-entry=0B cache-max-size-lazy-result=0B; do
  curl -s -o /dev/null "http://localhost:7015/?access-token=$TOK&$p"
done

../run_benchmark.sh \
  --endpoint "http://localhost:7015" \
  --clear-url "http://localhost:7015/?access-token=$TOK&cmd=clear-cache" \
  -t 300 -o results/qlever.tsv
```

`--endpoint` points the shared harness at QLever's SPARQL endpoint; `--clear-url`
is hit before every measured run. Results land in `results/` (gitignored).

## Notes

- QLever's published SPARQLoscope numbers are on the **core DBLP** dump (~502 M
  triples), not this KG+citations tar (~1.5 B). Our runs use the larger tar for
  *both* engines, so they compare to each other, not to the published table.
- Record the QLever image digest, dataset snapshot, and machine specs alongside
  any results.
