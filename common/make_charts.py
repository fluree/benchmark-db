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


def scaling_chart():
    # Fluree v4.0.6 geo-mean (ms) as the box shrinks 4×; all 105/105.
    rows = [
        ("16c / 64 GB", 19),
        ("8c / 32 GB", 20),
        ("4c / 16 GB", 25),
    ]
    qlever_full = 202  # 2nd-best engine geo mean, on the FULL 16c/64GB box
    W, H = 760, 380
    L, R, T, B = 60, 30, 70, 70
    pw = W - L - R
    ph = H - T - B
    ymax = 220.0
    n = len(rows)
    slot = pw / n
    bw = slot * 0.5

    def y(v):
        return T + ph - (v / ymax) * ph

    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
         f"viewBox='0 0 {W} {H}' {FONT}>"]
    s.append(f"<rect width='{W}' height='{H}' fill='white'/>")
    s.append(f"<text x='20' y='26' font-size='17' font-weight='700' fill='{INK}'>"
             "Fluree scales down 4× — performance virtually unchanged</text>")
    s.append(f"<text x='20' y='46' font-size='12.5' fill='{MUTED}'>"
             "DBLP-core · geometric-mean query time · every config 105/105 · lower is better</text>")
    for gv in (0, 50, 100, 150, 200):
        gy = y(gv)
        s.append(f"<line x1='{L}' y1='{gy:.1f}' x2='{W-R}' y2='{gy:.1f}' "
                 f"stroke='{GRID}' stroke-width='1'/>")
        s.append(f"<text x='{L-8}' y='{gy+4:.1f}' font-size='10.5' fill='{MUTED}' "
                 f"text-anchor='end'>{gv}</text>")
    ry = y(qlever_full)
    s.append(f"<line x1='{L}' y1='{ry:.1f}' x2='{W-R}' y2='{ry:.1f}' "
             f"stroke='{OTHER}' stroke-width='2' stroke-dasharray='7 4'/>")
    s.append(f"<text x='{W-R}' y='{ry-7:.1f}' font-size='11.5' fill='{MUTED}' "
             f"text-anchor='end' font-weight='600'>QLever — next fastest engine, on the full 16c/64 GB box (202 ms)</text>")
    for i, (label, v) in enumerate(rows):
        cx = L + i * slot + slot / 2
        bx = cx - bw / 2
        by = y(v)
        s.append(f"<rect x='{bx:.1f}' y='{by:.1f}' width='{bw:.1f}' height='{T+ph-by:.1f}' "
                 f"rx='3' fill='{FLUREE}'/>")
        s.append(f"<text x='{cx:.1f}' y='{by-8:.1f}' font-size='12' font-weight='700' "
                 f"fill='{INK}' text-anchor='middle'>{v} ms</text>")
        s.append(f"<text x='{cx:.1f}' y='{H-B+18:.1f}' font-size='11' fill='{INK}' "
                 f"text-anchor='middle'>{esc(label)}</text>")
    s.append(f"<text x='20' y='{H-18}' font-size='11.5' fill='{MUTED}'>"
             "Geo mean moves just 19 → 20 → 25 ms as the box shrinks 4× — and the 1/4-box result "
             "is still 8× faster than the next fastest engine on the full box.</text>")
    s.append("</svg>")
    return "\n".join(s)


def main():
    os.makedirs(OUT, exist_ok=True)

    # Penalized geo mean per the SPARQLoscope paper: a failed/timed-out query
    # counts as 2x the 180 s timeout (P=2).
    dblp_rows = [
        ("Fluree",          19.4,   "1.0×",   "105/105"),
        ("QLever",         202,    "10.4×",   "105/105"),
        ("Virtuoso",       300,    "15.4×",   "103/105"),
        ("MillenniumDB",  1664,      "86×",   "103/105"),
        ("Jena",         67700,    "3487×",    "34/105"),
        ("Oxigraph",     87000,    "4486×",    "39/105"),
        ("Blazegraph",  333000,   "17158×",     "3/105"),
    ]
    open(os.path.join(OUT, "dblp-core-geomean.svg"), "w").write(
        geomean_chart(
            dblp_rows,
            "DBLP-core · geometric-mean query time (penalized, P=2)",
            "561M triples · 7 engines, one box (m7a.4xlarge 16c/64GB) · Fluree v4.0.6 · "
            "failed query = 2× the 180 s timeout · linear, lower is better",
            hi=2000, nticks=4, cap=2000))

    open(os.path.join(OUT, "dblp-core-scaling.svg"), "w").write(scaling_chart())

    # Penalized geo mean per the SPARQLoscope paper: a failed/timed-out query
    # counts as 2x the 300 s timeout (P=2).
    wd_rows = [
        ("Fluree",          363,  "1.0×", "105/105"),
        ("QLever",         3821, "10.5×",  "91/105"),
        ("Virtuoso",      13000, "35.8×",  "81/105"),
        ("MillenniumDB",  28800, "79.2×",  "67/105"),
        ("Jena",         151500,  "417×",  "31/105"),
    ]
    open(os.path.join(OUT, "wikidata-truthy-geomean.svg"), "w").write(
        geomean_chart(
            wd_rows,
            "Wikidata-truthy (8.19B triples) · geometric-mean query time (penalized, P=2)",
            "5 engines, one box (r7a.16xlarge 64c/512GB) · Fluree v4.0.6 · "
            "failed query = 2× the 300 s timeout · linear, lower is better",
            hi=30000, nticks=6, cap=30000))

    print("wrote assets/dblp-core-geomean.svg, assets/dblp-core-scaling.svg, "
          "assets/wikidata-truthy-geomean.svg")


if __name__ == "__main__":
    main()
