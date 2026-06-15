#!/usr/bin/env python3
"""Render the BSBM Explore concurrency-scaling chart (QMpH vs client count) for the
3-engine comparison, at the 100M headline scale. Hand-rolled SVG (no third-party deps,
matching common/make_charts.py) so it renders as a plain <img> on GitHub.

  python3 make_explore_scaling_chart.py
  # -> ../../../../assets/bsbm-explore-scaling.svg

Data: Explore SELECT-subset, deep-warm (w200/r100), 100M, from summary.tsv.
"""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "..",
                   "assets", "bsbm-explore-scaling.svg")
FLUREE = "#0d9488"   # teal
VIRT = "#6366f1"     # indigo
QLEVER = "#f59e0b"   # amber
INK = "#1e293b"
MUTED = "#64748b"
GRID = "#e2e8f0"
FONT = "font-family='-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif'"

CLIENTS = [1, 4, 8, 16, 32]
SERIES = [
    ("Fluree v4.0.6", FLUREE, [9757, 36869, 69793, 115903, 115929]),
    ("Virtuoso 7",    VIRT,   [6782, 15298, 26238, 47910, 51339]),
    ("QLever",        QLEVER, [2145, 6345, 9699, 16399, 22408]),
]

W, H = 720, 420
ML, MR, MT, MB = 70, 150, 56, 50   # margins (right margin holds the legend)
PW, PH = W - ML - MR, H - MT - MB
YMAX = 120000
NT = 6


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def x(i):  # category position (even spacing)
    return ML + PW * i / (len(CLIENTS) - 1)


def y(v):
    return MT + PH * (1 - v / YMAX)


def main():
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
         f"viewBox='0 0 {W} {H}' {FONT}>"]
    s.append(f"<rect width='{W}' height='{H}' fill='white'/>")
    s.append(f"<text x='{ML}' y='26' font-size='17' font-weight='700' fill='{INK}'>"
             f"BSBM Explore — throughput vs concurrency (100M)</text>")
    s.append(f"<text x='{ML}' y='44' font-size='12' fill='{MUTED}'>"
             f"QMpH (query mixes/hour, higher is better) · SELECT-subset, deep-warm · "
             f"one m7a.4xlarge box (16 cores)</text>")

    # y gridlines + labels
    for t in range(NT):
        v = YMAX * t / (NT - 1)
        yy = y(v)
        s.append(f"<line x1='{ML}' y1='{yy:.1f}' x2='{ML+PW}' y2='{yy:.1f}' "
                 f"stroke='{GRID}'/>")
        s.append(f"<text x='{ML-8}' y='{yy+4:.1f}' font-size='11' fill='{MUTED}' "
                 f"text-anchor='end'>{int(v/1000)}k</text>")
    # x labels
    for i, c in enumerate(CLIENTS):
        s.append(f"<text x='{x(i):.1f}' y='{MT+PH+20}' font-size='11' fill='{MUTED}' "
                 f"text-anchor='middle'>{c}</text>")
    s.append(f"<text x='{ML+PW/2:.1f}' y='{MT+PH+42}' font-size='12' fill='{INK}' "
             f"text-anchor='middle'>concurrent clients</text>")

    # series lines + points
    for name, col, vals in SERIES:
        pts = " ".join(f"{x(i):.1f},{y(v):.1f}" for i, v in enumerate(vals))
        w = 3.2 if col == FLUREE else 2
        s.append(f"<polyline points='{pts}' fill='none' stroke='{col}' "
                 f"stroke-width='{w}'/>")
        for i, v in enumerate(vals):
            s.append(f"<circle cx='{x(i):.1f}' cy='{y(v):.1f}' r='3.4' fill='{col}'/>")
        # end label at the right
        ly = y(vals[-1])
        s.append(f"<text x='{ML+PW+10}' y='{ly+4:.1f}' font-size='12' "
                 f"font-weight='{'700' if col==FLUREE else '400'}' fill='{col}'>"
                 f"{esc(name)}</text>")
        s.append(f"<text x='{ML+PW+10}' y='{ly+19:.1f}' font-size='10' fill='{MUTED}'>"
                 f"{vals[-1]:,} @32</text>")

    s.append("</svg>")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w").write("\n".join(s))
    print("wrote", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
