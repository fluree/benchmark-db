# Oxigraph (native)

Single Rust binary, RocksDB-backed. Prebuilt Linux binary from GitHub releases.

## Install + load

```bash
mkdir ~/oxigraph && cd ~/oxigraph
curl -sL -o oxigraph https://github.com/oxigraph/oxigraph/releases/download/v0.5.8/oxigraph_v0.5.8_x86_64_linux_gnu
chmod +x oxigraph
./oxigraph load --location ~/oxigraph/data --file ~/data/dblp.ttl --format nt --lenient
```

- **Import time is "till ready", which includes RocksDB compaction.** DBLP-core:
  329 s parse @ 1.70 M t/s **+ ~243 s compaction = 572 s**, 43 GB index,
  561,477,456 triples. The engine isn't queryable until compaction settles.

## Serve + query — two gotchas

Oxigraph **(1)** has no server-side query timeout (can't cancel a running query,
issue #1336) and **(2)** has no COUNT fastpath (a full `COUNT(*)` over 561 M takes
~224 s). On DBLP-core it **times out on ~⅔ of queries** and a `DISTINCT COUNT` can
blow memory. So:

- Run it **memory-capped** under systemd (`MemoryMax`), so a runaway query gets
  cgroup-killed instead of taking down the box (an uncapped run alongside other
  servers OOM-locked the host once).
- Run it **alone** on the box (the cap assumes the whole box is Oxigraph's).
- Use a **per-query restart-on-failure** wrapper (mirrors their
  `util/oxigraph-helper.sh`): 1 run per query, 180 s timeout (their Oxigraph
  value); on timeout/error, record it and restart the server before the next
  query. This is a documented deviation from the warmup+median-of-3 protocol —
  read Oxigraph's results as **completed-vs-timed-out**, not directly comparable.

```bash
sudo systemd-run -p MemoryMax=52G -p MemorySwapMax=0 --unit=oxbench --collect \
  ~/oxigraph/oxigraph serve-read-only -l ~/oxigraph/data -b localhost:7878
# endpoint: POST http://localhost:7878/query
```

See `~/run_oxigraph_safe.sh` (the wrapper used for the run) — it writes
`oxigraph.tsv` directly in the runner's TSV format. DBLP-core: 36/105 completed
within 180 s, 69 timed out.
