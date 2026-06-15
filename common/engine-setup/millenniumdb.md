# MillenniumDB (native)

C++/CMake; build from source. antlr4 runtime is vendored in the repo (no submodule).

## Build

```bash
sudo apt-get update          # fresh box: refresh index first (else pkgs "not located")
sudo apt-get install -y build-essential cmake g++ git make \
  libboost-all-dev libicu-dev libncurses-dev libssl-dev      # all four -dev libs required
git clone --depth 1 https://github.com/MillenniumDB/MillenniumDB.git ~/mdb-src
cd ~/mdb-src
cmake -B build -D CMAKE_BUILD_TYPE=Release
cmake --build build -j15 --target install    # binary: build/bin/mdb
```

The `install` target may exit non-zero — harmless; `build/bin/mdb` is what we use.
(`mdb --version` → v1.0.0.)

## Import

```bash
~/mdb-src/build/bin/mdb import ~/data/dblp.ttl ~/mdb-db \
  --format ttl --buffer-strings 20GB --buffer-tensors 20GB
```

- **Compressed input via stdin** (avoids decompressing a huge dump to disk):
  ```bash
  pigz -dc ~/data/latest-truthy.nt.gz | \
    ~/mdb-src/build/bin/mdb import ~/mdb-db --format ttl \
      --buffer-strings 100GB --buffer-tensors 100GB     # db-dir first, data on stdin
  ```
  N-Triples parses fine under `--format ttl` (it's a Turtle subset).
- **Scale the buffers to RAM.** The paper used `--buffer-strings 40GB
  --buffer-tensors 40GB` (= 80 GB) on a big box; on a 64 GB box that OOMs, so use
  **20 GB + 20 GB**. For a 512 GB box loading 8 B truthy, **100 GB + 100 GB**. Index ~19 GB at 561 M.

## Serve + query

```bash
~/mdb-src/build/bin/mdb server ~/mdb-db --port 1234 --threads <N> &
# endpoint: http://localhost:1234/sparql
../../common/run_benchmark.sh --endpoint http://localhost:1234/sparql \
  -r 3 -w 1 -t 180 -o reports/<ds>/engines/mdb.tsv     # DBLP-core: 180 s; billion-scale: 300 s
```

(Check `mdb server --help` for the exact timeout/buffer flags; the paper used
`--timeout 180 --versioned-buffer 22GB --unversioned-buffer 2GB --strings-static
4GB --strings-dynamic 4GB` — scale to 64 GB. If the endpoint wants url-encoded
`query=`, add `--post-form` to the runner.)

> **DBLP-core run:** import 1,241 s (0.45 M triples/s, ~40 GB peak RAM), 21 GB index;
> **103/105** queries completed (`number-of-objects` / `number-of-subjects` time out on
> the full distinct scan at 180 s). See the DBLP-core REPORT for full results.
