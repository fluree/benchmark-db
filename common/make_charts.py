#!/usr/bin/env python3
"""
Generate the headline SVG charts for the root README (no third-party deps, so the
output renders as plain <img> on GitHub's markdown viewer).

  python3 common/make_charts.py
  # -> assets/dblp-core-geomean.svg
  #    assets/dblp-core-scaling.svg
  #    assets/wikidata-truthy-geomean.svg

Numbers are the published aggregates from
benchmarks/sparqloscope/reports/{dblp-core,wikidata-truthy}/ (REPORT.md /
fluree-scaling/README.md).
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")
FLUREE = "#0d9488"   # teal — Fluree
OTHER = "#94a3b8"    # slate — other engines
INK = "#1e293b"
MUTED = "#64748b"
GRID = "#e2e8f0"
FONT = "font-family='-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif'"


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def geomean_chart(rows, title, subtitle, lo=100.0, hi=30000.0):
    """Horizontal log-scale bar chart of geo-mean query time, Fluree highlighted.

    rows: list of (engine, geo_mean_ms, ratio_label, passed), fastest first.
    """
    L, R, T, B = 150, 150, 64, 40
    row_h = 37
    W = 760
    H = T + B + len(rows) * row_h
    pw = W - L - R
    bh = row_h * 0.6
    lx = math.log10(lo)
    span = math.log10(hi) - lx

    def x(v):
        return L + (math.log10(max(v, lo)) - lx) / span * pw

    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
         f"viewBox='0 0 {W} {H}' {FONT}>"]
    s.append(f"<rect width='{W}' height='{H}' fill='white'/>")
    s.append(f"<text x='20' y='26' font-size='17' font-weight='700' fill='{INK}'>"
             f"{esc(title)}</text>")
    s.append(f"<text x='20' y='46' font-size='12.5' fill='{MUTED}'>{esc(subtitle)}</text>")
    # gridlines: the lo boundary + each decade within (lo, hi]
    ticks = [lo] + [10 ** k for k in range(int(math.floor(math.log10(lo))) + 1,
                                            int(math.floor(math.log10(hi))) + 1)
                    if 10 ** k > lo]
    for gv in ticks:
        gx = x(gv)
        gl = f"{int(gv)} ms" if gv < 1000 else f"{int(gv // 1000)} s"
        s.append(f"<line x1='{gx:.1f}' y1='{T}' x2='{gx:.1f}' y2='{H-B}' "
                 f"stroke='{GRID}' stroke-width='1'/>")
        s.append(f"<text x='{gx:.1f}' y='{H-B+16}' font-size='11' fill='{MUTED}' "
                 f"text-anchor='middle'>{gl}</text>")
    for i, (name, v, ratio, passed) in enumerate(rows):
        y = T + i * row_h + (row_h - bh) / 2
        col = FLUREE if i == 0 else OTHER
        s.append(f"<text x='{L-10}' y='{y+bh/2+4:.1f}' font-size='12.5' "
                 f"font-weight='{'700' if i==0 else '400'}' fill='{INK}' "
                 f"text-anchor='end'>{esc(name)}</text>")
        s.append(f"<rect x='{L}' y='{y:.1f}' width='{x(v)-L:.1f}' height='{bh:.1f}' "
                 f"rx='3' fill='{col}'/>")
        vlabel = f"{v} ms" if v < 1000 else f"{v/1000:.1f} s"
        s.append(f"<text x='{x(v)+8:.1f}' y='{y+bh/2+4:.1f}' font-size='12' "
                 f"font-weight='{'700' if i==0 else '400'}' fill='{INK}'>"
                 f"{vlabel}  <tspan fill='{MUTED}'>{ratio} · {passed}</tspan></text>")
    s.append("</svg>")
    return "\n".join(s)


def scaling_chart():
    # Fluree arith-mean (ms) as the box shrinks; all 105/105.
    rows = [
        ("16c / 64 GB", 981),
        ("16c / 32 GB", 1043),
        ("8c / 32 GB", 1028),
        ("8c / 16 GB", 1044),
        ("4c / 16 GB", 1062),
    ]
    qlever_full = 1986  # 2nd-best engine, on the FULL 16c/64GB box
    W, H = 760, 380
    L, R, T, B = 60, 30, 70, 70
    pw = W - L - R
    ph = H - T - B
    ymax = 2200.0
    n = len(rows)
    slot = pw / n
    bw = slot * 0.5

    def y(v):
        return T + ph - (v / ymax) * ph

    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
         f"viewBox='0 0 {W} {H}' {FONT}>"]
    s.append(f"<rect width='{W}' height='{H}' fill='white'/>")
    s.append(f"<text x='20' y='26' font-size='17' font-weight='700' fill='{INK}'>"
             "Fluree scales down 4× and still beats the field</text>")
    s.append(f"<text x='20' y='46' font-size='12.5' fill='{MUTED}'>"
             "DBLP-core · arithmetic-mean query time · every config 105/105 · lower is better</text>")
    for gv in (0, 500, 1000, 1500, 2000):
        gy = y(gv)
        s.append(f"<line x1='{L}' y1='{gy:.1f}' x2='{W-R}' y2='{gy:.1f}' "
                 f"stroke='{GRID}' stroke-width='1'/>")
        s.append(f"<text x='{L-8}' y='{gy+4:.1f}' font-size='10.5' fill='{MUTED}' "
                 f"text-anchor='end'>{gv}</text>")
    ry = y(qlever_full)
    s.append(f"<line x1='{L}' y1='{ry:.1f}' x2='{W-R}' y2='{ry:.1f}' "
             f"stroke='{OTHER}' stroke-width='2' stroke-dasharray='7 4'/>")
    s.append(f"<text x='{W-R}' y='{ry-7:.1f}' font-size='11.5' fill='{MUTED}' "
             f"text-anchor='end' font-weight='600'>QLever — 2nd place, full 16c/64 GB box (1,986 ms)</text>")
    for i, (label, v) in enumerate(rows):
        cx = L + i * slot + slot / 2
        bx = cx - bw / 2
        by = y(v)
        s.append(f"<rect x='{bx:.1f}' y='{by:.1f}' width='{bw:.1f}' height='{T+ph-by:.1f}' "
                 f"rx='3' fill='{FLUREE}'/>")
        s.append(f"<text x='{cx:.1f}' y='{by-8:.1f}' font-size='12' font-weight='700' "
                 f"fill='{INK}' text-anchor='middle'>{v:,} ms</text>")
        s.append(f"<text x='{cx:.1f}' y='{H-B+18:.1f}' font-size='11.5' fill='{INK}' "
                 f"text-anchor='middle'>{esc(label)}</text>")
    s.append(f"<text x='20' y='{H-18}' font-size='11.5' fill='{MUTED}'>"
             "Even at 1/4 the cores and RAM (4c/16 GB), Fluree (1,062 ms) is 1.9× faster "
             "than QLever on the full box.</text>")
    s.append("</svg>")
    return "\n".join(s)


def main():
    os.makedirs(OUT, exist_ok=True)

    dblp_rows = [
        ("Fluree",        124,  "1.0×",   "105/105"),
        ("QLever",        199,  "1.6×",   "105/105"),
        ("Virtuoso",      611,  "4.9×",   "102/105"),
        ("MillenniumDB", 1565, "12.6×",   "103/105"),
        ("Jena",         5649, "45.4×",    "69/105"),
        ("Oxigraph",     6042, "48.6×",    "36/105"),
        ("Blazegraph",  20500, "164.9×",    "3/105"),
    ]
    open(os.path.join(OUT, "dblp-core-geomean.svg"), "w").write(
        geomean_chart(
            dblp_rows,
            "DBLP-core · geometric-mean query time",
            "561M triples · all 7 engines on one box (AWS m7a.4xlarge, 16c / 64 GB) · "
            "log scale, lower is better",
            lo=100.0, hi=30000.0))

    open(os.path.join(OUT, "dblp-core-scaling.svg"), "w").write(scaling_chart())

    wd_rows = [
        ("Fluree",        994, "1.0×",  "94/105"),
        ("QLever",       1690, "1.7×",  "91/105"),
        ("MillenniumDB", 3896, "3.9×",  "63/105"),
        ("Virtuoso",     6294, "6.3×",  "80/105"),
    ]
    open(os.path.join(OUT, "wikidata-truthy-geomean.svg"), "w").write(
        geomean_chart(
            wd_rows,
            "Wikidata-truthy (8.19B triples) · geometric-mean query time",
            "4 engines on one box (AWS r7a.16xlarge, 64c / 512 GB) · log scale, lower is better",
            lo=500.0, hi=10000.0))

    print("wrote assets/dblp-core-geomean.svg, assets/dblp-core-scaling.svg, "
          "assets/wikidata-truthy-geomean.svg")


if __name__ == "__main__":
    main()
