# Fluree (native)

Fluree is a **Rust** workspace (github.com/fluree/db, public). The engine CLI is
the `fluree` binary (crate `fluree-db-cli`).

## Install (v4.0.6 release — recommended)

Install the prebuilt native `fluree` binary straight from the GitHub release with
the official shell installer (no Rust toolchain, no source build, no repo access):

```bash
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/fluree/db/releases/latest/download/fluree-db-cli-installer.sh | sh
```

The installer drops the binary in **`~/bin`** and writes a PATH helper. Activate it
and confirm the version:

```bash
source "$HOME/bin/env"      # or restart the shell
fluree --version           # -> fluree 4.0.6
```

Notes:
- This gives the **same native binary** we benchmark — run it directly, not the
  Docker image, to match the other engines.
- Pin a specific version instead of `latest` by swapping the URL path, e.g.
  `.../releases/download/v4.0.6/fluree-db-cli-installer.sh`.
- Other install channels (Docker, Homebrew, Windows) are listed at
  **<https://labs.flur.ee>**.

The published benchmarks were run on **Fluree v4.0.6**.

## Build from source (optional — for a specific branch/commit)

Only needed to test an unreleased branch. Build on the target arch (boxes are x86_64):

```bash
sudo apt-get update && sudo apt-get install -y \
  build-essential pkg-config libssl-dev cmake clang protobuf-compiler git
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
. "$HOME/.cargo/env"
git clone --branch <branch> --single-branch https://github.com/fluree/db.git ~/db-src
cd ~/db-src && cargo build --release -p fluree-db-cli      # -> target/release/fluree
```

(The one test-only submodule, `testsuite-sparql/rdf-tests`, is not needed to build
the binary.)

## Import

With the release on PATH (`source ~/bin/env`), use the bare `fluree` command; a
source build is at `~/db-src/target/release/fluree`.

```bash
mkdir ~/fluree-run && cd ~/fluree-run
fluree create dblp --from ~/data/dblp.ttl
```

- N-Triples is routed to the Turtle importer by the `.ttl` extension; `.gz`/`.zst`
  are decoded transparently (`--from dblp.nt.gz` also works).
- Auto settings on a 64 GB box: memory budget ~37.75 GB (60% RAM), **parallelism 9**
  (capped by the memory budget), 768 MB chunks. The import is **I/O / serial-reader
  bound, not CPU-bound** — forcing `--parallelism 16` gives no speedup (measured
  1.07 vs 1.14 M tr/s). The lever for faster import is disk throughput, not cores.
- DBLP-core: 504 s, 1.14 M tr/s, peak RSS 21.9 GB, 27 GB index. Counts 561,544,658
  distinct triples (dedups exact-duplicate N-Triples lines).

> Import note: a large **uncompressed** file with **high prefix cardinality**
> (≥256 prefixes, e.g. Wikidata) could silently import 0 chunks
> (`committed_chunks=0`). DBLP-core is low-cardinality and unaffected;
> for high-cardinality data, import the **gzipped** file.

## Serve + query

```bash
cd ~/fluree-run
fluree server start --listen-addr 0.0.0.0:8090 --log-level info
# health: curl localhost:8090/health ; endpoint: POST /v1/fluree/query/dblp:main
```

Fluree has **no result cache**, so the runner needs no `--clear-url`:

```bash
../../common/run_benchmark.sh --endpoint http://localhost:8090/v1/fluree/query/dblp:main \
  -r 3 -w 1 -t 180 -o reports/<ds>/engines/fluree.tsv     # DBLP-core: 180 s; billion-scale: 300 s
```

CLI sanity query (exercises the count fastpath): `fluree query dblp -f queries/number-of-triples.sparql --bench`.
