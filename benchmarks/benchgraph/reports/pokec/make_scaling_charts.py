#!/usr/bin/env python3
"""Render the Pokec scale charts: geometric-mean latency vs graph scale, one line per
engine, one chart for reads and one for durable writes. Hand-rolled SVG (no third-party
deps, matching common/make_charts.py and the BSBM scaling chart) so it renders as a plain
<img> on GitHub.

  python3 make_scaling_charts.py
  # -> ../../../../assets/pokec-reads-scaling.svg, pokec-writes-scaling.svg

Data: summary.tsv next to this script (written by ../../gen_report.py). Geo means are over
the queries every engine answered at that scale, exactly as in REPORT.md section 1.
"""
import csv
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "..", "..", "assets")

FLUREE = "#0d9488"    # teal (same as the BSBM chart)
FALKOR = "#e11d48"    # rose
MEMGRAPH = "#f59e0b"  # amber
NEO4J = "#6366f1"     # indigo
INK = "#1e293b"
MUTED = "#64748b"
GRID = "#e2e8f0"
FONT = "font-family='-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif'"

with open(os.path.join(HERE, "meta.json")) as f:
    VERSION = json.load(f)["engines"]["fluree"]["version"]

ENGINES = [("fluree", f"Fluree {VERSION}", FLUREE), ("falkordb", "FalkorDB", FALKOR),
           ("memgraph", "Memgraph", MEMGRAPH), ("neo4j", "Neo4j", NEO4J)]
SCALES = [("small", "small", "10 k nodes"), ("medium", "medium", "100 k nodes"),
          ("large", "large", "1.6 M nodes")]

W, H = 760, 440
ML, MR, MT, MB = 70, 170, 84, 58   # right margin holds the end labels
PW, PH = W - ML - MR, H - MT - MB


def geo_means(kind):
    rows = list(csv.DictReader(open(os.path.join(HERE, "summary.tsv")), delimiter="\t"))
    out = {}
    for e, _, _ in ENGINES:
        vals = []
        for s, _, _ in SCALES:
            ms = []
            for r in rows:
                if r["scale"] != s or r["kind"] != kind:
                    continue
                ms.append(float(r[f"{e}_ms"]))
            expected = 27 if kind == "read" else 8
            if len(ms) != expected:
                raise ValueError(f"Expected {expected} {kind} queries for {e}/{s}")
            vals.append(math.exp(sum(map(math.log, ms)) / len(ms)))
        out[e] = vals
    return out


def nice_max(v):
    for step in (1, 2, 2.5, 5, 10, 20, 25, 50):
        top = math.ceil(v / step) * step
        if top / step <= 6:
            return top, step
    return math.ceil(v), 1


def spread(ys, gap):
    """Push end-label y positions apart so no two are closer than `gap`, keeping order."""
    order = sorted(range(len(ys)), key=lambda i: ys[i])
    placed = {}
    last = -1e9
    for i in order:
        y = max(ys[i], last + gap)
        placed[i] = y
        last = y
    overflow = last - (MT + PH)
    if overflow > 0:  # shift the stack up if it ran off the bottom of the plot
        for i in placed:
            placed[i] -= overflow
    return [placed[i] for i in range(len(ys))]


def chart(kind, title, subtitle, fname):
    gm = geo_means(kind)
    ymax, step = nice_max(max(max(v) for v in gm.values()) * 1.08)

    def x(i):
        return ML + PW * i / (len(SCALES) - 1)

    def y(v):
        return MT + PH * (1 - v / ymax)

    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
         f"viewBox='0 0 {W} {H}' {FONT}>",
         f"<rect width='{W}' height='{H}' fill='white'/>",
         f"<text x='{ML}' y='26' font-size='17' font-weight='700' fill='{INK}'>{title}</text>",
         f"<text x='{ML}' y='44' font-size='12' fill='{MUTED}'>{subtitle}</text>"]

    s.append(f"<text x='{ML}' y='66' font-size='13' font-weight='700' "
             f"fill='{INK}'>LOWER IS FASTER · latency in milliseconds</text>")

    t = 0.0
    while t <= ymax + 1e-9:
        yy = y(t)
        s.append(f"<line x1='{ML}' y1='{yy:.1f}' x2='{ML+PW}' y2='{yy:.1f}' stroke='{GRID}'/>")
        label = f"{t:g}"
        s.append(f"<text x='{ML-8}' y='{yy+4:.1f}' font-size='11' fill='{MUTED}' "
                 f"text-anchor='end'>{label}</text>")
        t += step
    s.append(f"<text x='18' y='{MT+PH/2:.1f}' font-size='12' fill='{INK}' text-anchor='middle' "
             f"transform='rotate(-90 18 {MT+PH/2:.1f})'>geo-mean latency, ms (lower is better)</text>")

    for i, (_, name, nodes) in enumerate(SCALES):
        s.append(f"<text x='{x(i):.1f}' y='{MT+PH+20}' font-size='12' fill='{INK}' "
                 f"text-anchor='middle'>{name}</text>")
        s.append(f"<text x='{x(i):.1f}' y='{MT+PH+35}' font-size='10' fill='{MUTED}' "
                 f"text-anchor='middle'>{nodes}</text>")

    # draw the other engines first so Fluree's line sits on top
    for e, _, col in reversed(ENGINES):
        vals = gm[e]
        pts = " ".join(f"{x(i):.1f},{y(v):.1f}" for i, v in enumerate(vals))
        w = 3.2 if e == "fluree" else 2
        s.append(f"<polyline points='{pts}' fill='none' stroke='{col}' stroke-width='{w}'/>")
        for i, v in enumerate(vals):
            s.append(f"<circle cx='{x(i):.1f}' cy='{y(v):.1f}' r='3.4' fill='{col}'/>")

    ends = spread([y(gm[e][-1]) for e, _, _ in ENGINES], gap=30)
    for (e, name, col), ly in zip(ENGINES, ends):
        bold = "700" if e == "fluree" else "400"
        s.append(f"<text x='{ML+PW+12}' y='{ly+4:.1f}' font-size='12' font-weight='{bold}' "
                 f"fill='{col}'>{name}</text>")
        s.append(f"<text x='{ML+PW+12}' y='{ly+18:.1f}' font-size='10' fill='{MUTED}'>"
                 f"{gm[e][-1]:.2f} ms at large</text>")

    s.append("</svg>")
    path = os.path.join(ASSETS, fname)
    os.makedirs(ASSETS, exist_ok=True)
    open(path, "w").write("\n".join(s))
    print("wrote", os.path.relpath(path), {e: [round(v, 2) for v in gm[e]] for e, _, _ in ENGINES})


def main():
    box = "one m7a.4xlarge (16c/64GB) · persistent connections"
    chart("read", "Pokec reads · geometric-mean latency",
          f"27 queries · pristine store · {box}", "pokec-reads-scaling.svg")
    chart("write", "Pokec durable writes · geometric-mean latency",
          f"8 queries · per-commit durability · {box}", "pokec-writes-scaling.svg")


if __name__ == "__main__":
    main()
