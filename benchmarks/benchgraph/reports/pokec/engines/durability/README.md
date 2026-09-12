# Durability verification — Pokec small, 40 writes per engine

`strace -f --seccomp-bpf -c -e trace=fsync,fdatasync,sync_file_range,syncfs` attached to each
engine's server process over an identical 40-write pass (the 8 write queries × 5 runs, shared
params), in the exact configuration the report measures, plus the shipped defaults of the two
in-memory engines for contrast. Raw `strace -c` output and runner TSVs are alongside.

| configuration | writes | fdatasync | fsync | syncfs | sync_file_range | durable per commit? |
|---|--:|--:|--:|--:|--:|---|
| FalkorDB 4.20.4, AOF appendfsync always (measured) | 40 | 40 | 0 | 0 | 0 | yes |
| FalkorDB 4.20.4, shipped default | 40 | 0 | 0 | 0 | 0 | no |
| Fluree v4.2.1, FLUREE_STORAGE_FSYNC=wal (measured) | 40 | 44 | 2 | 4 | 107 | yes |
| Memgraph 3.11.0, shipped default | 40 | 0 | 0 | 0 | 0 | no |
| Memgraph 3.11.0, --storage-wal-file-flush-every-n-tx=1 (measured) | 40 | 0 | 40 | 0 | 0 | yes |
| Neo4j 5.26.30, default (measured) | 40 | 57 | 0 | 0 | 0 | yes |

Fluree's `syncfs` calls are index-publish barriers and its `sync_file_range` calls are WAL
write-back hints; the per-commit durability point is the WAL `fdatasync`. Neo4j issues more than
one `fdatasync` per commit (transaction log plus checkpoint). Both in-memory engines issue none
in their shipped configuration.

These aggregate syscall counts document flush activity in the configured write pass;
they do not map each acknowledgement to a flush or substitute for crash-recovery testing.
To rerun the diagnostic on fresh small stores, use
[`verify-durability-box.sh`](../../../../verify-durability-box.sh) after following the
[reproduction instructions](../../REPORT.md#6-reproduce-it). The diagnostic timings are
kept separate from the published performance samples.
