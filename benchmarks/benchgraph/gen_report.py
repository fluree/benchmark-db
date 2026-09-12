#!/usr/bin/env python3
"""Build summary.tsv and the REPORT.md tables from per-engine raw runner TSVs.

Input dir layout: <indir>/<engine>_<scale>.tsv (bench_runner.py output; reads from the
pristine reads2 pass, writes from the full pass, merged per engine+scale).
Writes <outdir>/summary.tsv and prints the markdown tables (geo means, categories,
per-query appendix) to stdout, or to <outdir>/tables.md with --tables.
"""
import csv, math, os, statistics, sys, collections
ENGINES = [("fluree", "Fluree"), ("memgraph", "Memgraph"), ("neo4j", "Neo4j"), ("falkordb", "FalkorDB")]
SCALES = ["small", "medium", "large"]
CATS = [("Point lookup", ["arango__single_vertex_read", "match__pattern_cycle", "match__pattern_long", "match__pattern_short",
                          "match__vertex_on_label_property", "match__vertex_on_label_property_index", "match__vertex_on_property"]),
        ("Aggregate", ["aggregation__count", "aggregation__min_max_avg", "arango__aggregate", "arango__aggregate_with_distinct", "arango__aggregate_with_filter"]),
        ("Expansion", [f"arango__expansion_{i}{s}" for i in (1, 2, 3, 4) for s in ("", "_with_filter")]),
        ("Neighbourhood", ["arango__neighbours_2", "arango__neighbours_2_with_data", "arango__neighbours_2_with_data_and_filter", "arango__neighbours_2_with_filter"]),
        ("Shortest path", ["arango__allshortest_paths", "arango__shortest_path", "arango__shortest_path_with_filter"])]
HERE = os.path.dirname(os.path.abspath(__file__))

def short(q):
    return q.split("__", 1)[1] if "__" in q else q

def load(indir):
    kind = {r["query_id"]: r["kind"] for r in csv.DictReader(open(os.path.join(HERE, "query-set.tsv")), delimiter="\t")}
    med = {}  # (scale, engine) -> {qid: median}
    for s in SCALES:
        for e, _ in ENGINES:
            f = os.path.join(indir, f"{e}_{s}.tsv")
            if not os.path.exists(f):
                continue
            by = collections.defaultdict(list)
            for r in csv.DictReader(open(f), delimiter="\t"):
                if r["status"] in ("200", "ok", "OK") and r["time_ms"]:
                    by[r["query_id"]].append(float(r["time_ms"]))
            med[(s, e)] = {q: statistics.median(v) for q, v in by.items()}
    return kind, med

def gm(vals):
    vals = [v for v in vals if v is not None and v > 0]
    return math.exp(sum(map(math.log, vals)) / len(vals)) if vals else None

def ratio(f, x):
    if f is None or x is None:
        return "-"
    return f"{x / f:.2f}× faster" if x >= f else f"{f / x:.2f}× slower"

def fmt(v, bold=False):
    if v is None:
        return "-"
    s = f"{v:.2f}"
    return f"**{s}**" if bold else s

def row(label, vals, ratios=True, n=None):
    best = min([v for v in vals if v is not None], default=None)
    cells = [fmt(v, bold=(v is not None and v == best)) for v in vals]
    r = [label] + ([str(n)] if n is not None else []) + cells
    if ratios:
        r += [ratio(vals[0], v) for v in vals[1:]]
    return "| " + " | ".join(r) + " |"

def header(first, n=False, ratios=True):
    cols = [first] + (["n"] if n else []) + [lbl for _, lbl in ENGINES]
    align = ["---"] + (["--:"] if n else []) + ["---"] * len(ENGINES)
    if ratios:
        cols += [f"Fluree vs {lbl}" for _, lbl in ENGINES[1:]]
        align += ["--:"] * (len(ENGINES) - 1)
    return "| " + " | ".join(cols) + " |\n| " + " | ".join(align) + " |"

def main():
    indir = sys.argv[1]; outdir = sys.argv[2] if len(sys.argv) > 2 else indir
    kind, med = load(indir)
    scales = [s for s in SCALES if any((s, e) in med for e, _ in ENGINES)]
    # summary.tsv
    with open(os.path.join(outdir, "summary.tsv"), "w") as f:
        f.write("scale\tquery_id\tkind\t" + "\t".join(f"{e}_ms" for e, _ in ENGINES) + "\tf_over_mg\tf_over_neo\tf_over_fdb\n")
        for s in scales:
            for q in sorted(kind):
                vals = [med.get((s, e), {}).get(q) for e, _ in ENGINES]
                rs = [f"{v / vals[0]:.2f}" if (vals[0] and v) else "" for v in vals[1:]]
                f.write(f"{s}\t{q}\t{kind[q]}\t" + "\t".join("" if v is None else f"{v:.3f}" for v in vals) + "\t" + "\t".join(rs) + "\n")
    out = []
    for k, title in (("write", "Writes"), ("read", "Reads")):
        qs = [q for q in sorted(kind) if kind[q] == k]
        out += [f"### {title} — geometric mean (ms)", "", header("scale", n=True)]
        for s in scales:
            common = [q for q in qs if all(med.get((s, e), {}).get(q) for e, _ in ENGINES)]
            out.append(row(s, [gm([med[(s, e)][q] for q in common]) for e, _ in ENGINES], n=len(common)))
        out.append("")
    out += ["### Reads by category — geometric mean (ms)", ""]
    for s in scales:
        out += [f"**{s}**", "", "| category | n | " + " | ".join(l for _, l in ENGINES) + " | winner |", "|---|--:|" + "---|" * len(ENGINES) + "---|"]
        for cat, qs in CATS:
            common = [q for q in qs if all(med.get((s, e), {}).get(q) for e, _ in ENGINES)]
            vals = [gm([med[(s, e)][q] for q in common]) for e, _ in ENGINES]
            best = min(v for v in vals if v is not None)
            winner = [l for (e, l), v in zip(ENGINES, vals) if v == best][0]
            out.append(f"| {cat} | {len(common)} | " + " | ".join(fmt(v, v == best) for v in vals) + f" | {winner} |")
        out.append("")
    for k, title in (("write", "writes"), ("read", "reads")):
        out += [f"### Per query — {title} (median ms)", ""]
        for s in scales:
            out += [f"**{s}**", "", header("query")]
            for q in [q for q in sorted(kind) if kind[q] == k]:
                out.append(row(f"`{short(q)}`", [med.get((s, e), {}).get(q) for e, _ in ENGINES]))
            out.append("")
    text = "\n".join(out)
    if "--tables" in sys.argv:
        open(os.path.join(outdir, "tables.md"), "w").write(text)
    else:
        print(text)

if __name__ == "__main__":
    main()
