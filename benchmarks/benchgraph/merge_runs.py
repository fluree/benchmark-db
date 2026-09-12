"""Merge <scale>_<engine>_reads2.tsv (reads) + <scale>_<engine>_full.tsv (writes) into <engine>_<scale>.tsv."""
import csv, os, sys
src, dst = sys.argv[1], sys.argv[2]
kind = {r["query_id"]: r["kind"] for r in csv.DictReader(open(sys.argv[3]), delimiter="\t")}
os.makedirs(dst, exist_ok=True)
for s in ("small", "medium", "large"):
    for e in ("fluree", "memgraph", "neo4j", "falkordb"):
        r2, full = f"{src}/{s}_{e}_reads2.tsv", f"{src}/{s}_{e}_full.tsv"
        if not (os.path.exists(r2) and os.path.exists(full)):
            continue
        rows = []
        with open(r2) as f:
            rows += [r for r in csv.DictReader(f, delimiter="\t") if kind.get(r["query_id"]) == "read"]
        with open(full) as f:
            rows += [r for r in csv.DictReader(f, delimiter="\t") if kind.get(r["query_id"]) == "write"]
        hdr = ["query_id", "description", "run", "status", "time_ms", "result_size", "error"]
        with open(f"{dst}/{e}_{s}.tsv", "w") as f:
            f.write("\t".join(hdr) + "\n")
            for r in rows:
                f.write("\t".join(r.get(h, "") or "" for h in hdr) + "\n")
        print(f"{e}_{s}.tsv: {len(rows)} rows")
