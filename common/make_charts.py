#!/usr/bin/env python3
"""
Generate the headline SVG charts for the root README (no third-party deps, so the
output renders as plain <img> on GitHub's markdown viewer).

  python3 common/make_charts.py
  # -> assets/dblp-core-geomean.svg
  #    assets/wikidata-truthy-geomean.svg

Numbers are the published aggregates from
benchmarks/sparqloscope/reports/{dblp-core,wikidata-truthy}/ (REPORT.md / meta.json).
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


def geomean_chart(rows, title, subtitle, hi, nticks=5, cap=None):
    """Horizontal LINEAR-scale bar chart of geo-mean query time, Fluree highlighted.

    Bar length is exactly proportional to the value (truly to scale). rows: list of
    (engine, geo_mean_ms, ratio_label, passed), fastest first.

    hi     - axis maximum (ms). nticks - number of gridline steps.
    cap    - if set, any value > cap is drawn as a hatched "off-scale" bar clamped to
             `cap` and flagged, so one outlier (e.g. Blazegraph) doesn't crush the axis.
    """
    L, R, T, B = 150, 32, 64, 44
    row_h = 37
    W = 760
    H = T + B + len(rows) * row_h
    pw = W - L - R
    bh = row_h * 0.6
    axis_max = cap if cap else hi

    def x(v):
        return L + (min(max(v, 0), axis_max) / axis_max) * pw

    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
         f"viewBox='0 0 {W} {H}' {FONT}>"]
    s.append("<defs><pattern id='offscale' width='6' height='6' "
             "patternTransform='rotate(45)' patternUnits='userSpaceOnUse'>"
             f"<rect width='6' height='6' fill='{OTHER}'/>"
             "<line x1='0' y1='0' x2='0' y2='6' stroke='white' stroke-width='2'/>"
             "</pattern></defs>")
    s.append(f"<rect width='{W}' height='{H}' fill='white'/>")
    s.append(f"<text x='20' y='26' font-size='17' font-weight='700' fill='{INK}'>"
             f"{esc(title)}</text>")
    s.append(f"<text x='20' y='46' font-size='12.5' fill='{MUTED}'>{esc(subtitle)}</text>")
    # linear gridlines: 0 .. axis_max in nticks steps
    for k in range(nticks + 1):
        gv = axis_max * k / nticks
        gx = x(gv)
        gl = f"{gv/1000:g} s" if gv >= 1000 else f"{int(gv)} ms"
        s.append(f"<line x1='{gx:.1f}' y1='{T}' x2='{gx:.1f}' y2='{H-B}' "
                 f"stroke='{GRID}' stroke-width='1'/>")
        s.append(f"<text x='{gx:.1f}' y='{H-B+16}' font-size='11' fill='{MUTED}' "
                 f"text-anchor='middle'>{gl}</text>")
    for i, (name, v, ratio, passed) in enumerate(rows):
        y = T + i * row_h + (row_h - bh) / 2
        capped = cap is not None and v > cap
        col = FLUREE if i == 0 else OTHER
        s.append(f"<text x='{L-10}' y='{y+bh/2+4:.1f}' font-size='12.5' "
                 f"font-weight='{'700' if i==0 else '400'}' fill='{INK}' "
                 f"text-anchor='end'>{esc(name)}</text>")
        bx = x(v)
        fill = "url(#offscale)" if capped else col
        s.append(f"<rect x='{L}' y='{y:.1f}' width='{max(bx-L,2):.1f}' height='{bh:.1f}' "
                 f"rx='2' fill='{fill}'/>")
        vlabel = f"{v} ms" if v < 1000 else f"{v/1000:.1f} s"
        tail = f"{ratio} · {passed}" + ("  ▶ off-scale" if capped else "")
        full = f"{vlabel}   {tail}"
        # place the value label outside the bar if it fits, else inside (right-aligned)
        if bx + 8 + len(full) * 6.2 <= W - 2:
            s.append(f"<text x='{bx+8:.1f}' y='{y+bh/2+4:.1f}' font-size='12' "
                     f"font-weight='{'700' if i==0 else '400'}' fill='{INK}'>"
                     f"{vlabel}  <tspan fill='{MUTED}'>{esc(tail)}</tspan></text>")
        else:
            s.append(f"<text x='{bx-8:.1f}' y='{y+bh/2+4:.1f}' font-size='12' "
                     f"font-weight='700' fill='white' text-anchor='end'>"
                     f"{esc(full)}</text>")
    s.append("</svg>")
    return "\n".join(s)


def main():
    os.makedirs(OUT, exist_ok=True)

    # Penalized geo mean per the SPARQLoscope paper: a failed/timed-out query
    # counts as 2x the 180 s timeout (P=2).
    dblp_rows = [
        ("Fluree",          17.5,   "1.0×",   "105/105"),
        ("QLever",         202,    "11.5×",   "105/105"),
        ("Virtuoso",       300,    "17.1×",   "103/105"),
        ("MillenniumDB",  1664,      "95×",   "103/105"),
        ("Jena",         67700,    "3856×",    "34/105"),
        ("Oxigraph",     87000,    "4961×",    "39/105"),
        ("Blazegraph",  333000,   "18971×",     "3/105"),
    ]
    open(os.path.join(OUT, "dblp-core-geomean.svg"), "w").write(
        geomean_chart(
            dblp_rows,
            "DBLP-core · geometric-mean query time (penalized, P=2)",
            "561M triples · 7 engines, one box (m7a.4xlarge 16c/64GB) · Fluree v4.1.2 · "
            "failed query = 2× the 180 s timeout · linear, lower is better",
            hi=2000, nticks=4, cap=2000))

    # Penalized geo mean per the SPARQLoscope paper: a failed/timed-out query
    # counts as 2x the 300 s timeout (P=2).
    wd_rows = [
        ("Fluree",          367,  "1.0×", "105/105"),
        ("QLever",         3833, "10.4×",  "91/105"),
        ("Virtuoso",      12900, "35.1×",  "81/105"),
        ("MillenniumDB",  28700, "78.1×",  "67/105"),
        ("Jena",         151500,  "412×",  "31/105"),
    ]
    open(os.path.join(OUT, "wikidata-truthy-geomean.svg"), "w").write(
        geomean_chart(
            wd_rows,
            "Wikidata-truthy (8.19B triples) · geometric-mean query time (penalized, P=2)",
            "5 engines, one box (r7a.16xlarge 64c/512GB) · Fluree v4.0.6 · "
            "failed query = 2× the 300 s timeout · linear, lower is better",
            hi=30000, nticks=6, cap=30000))

    print("wrote assets/dblp-core-geomean.svg, assets/wikidata-truthy-geomean.svg")


if __name__ == "__main__":
    main()
