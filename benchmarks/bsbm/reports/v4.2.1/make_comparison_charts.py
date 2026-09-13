#!/usr/bin/env python3
"""Render the BSBM cross-engine charts from comparison.tsv: throughput (QMpH) vs client
count, one line per engine. Hand-rolled SVG (no third-party deps, same style as the Pokec
charts) so they render as a plain <img> on GitHub.

  python3 collect_comparison.py      # refresh comparison.tsv from the run archives
  python3 make_comparison_charts.py
  # -> ../../../../assets/bsbm-select-scaling.svg, bsbm-explore-virtuoso-scaling.svg,
  #    bsbm-bi-1m-scaling.svg, bsbm-update-1m-scaling.svg

Markers: filled = accepted cell (median of three repeats that passed every check);
hollow on a dashed segment = a median exists but the cell failed a check (result counts
differed between repeats, or spread over 5%); a cross on the axis = a repeat errored, so
the cell has no median.
"""
import csv
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "..", "..", "assets")

FLUREE = "#0d9488"    # teal (same as the Pokec charts)
QLEVER = "#f59e0b"    # amber
VIRTUOSO = "#6366f1"  # indigo
INK = "#1e293b"
MUTED = "#64748b"
GRID = "#e2e8f0"
FONT = "font-family='-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif'"

ENGINES = {"fluree": ("Fluree v4.2.1", FLUREE), "qlever": ("QLever 0.6.0", QLEVER),
           "virtuoso": ("Virtuoso 7.2.17", VIRTUOSO)}
SCALES = {"1m": ("1M", "724 k triples"), "100m": ("100M", "100 M triples"),
          "200m": ("200M", "200 M triples")}
HOSTS = "m7a.4xlarge database · separate m7a.2xlarge driver · median of 3 repeats"


def load():
    cells = {}
    with open(os.path.join(HERE, "comparison.tsv")) as f:
        for r in csv.DictReader(f, delimiter="\t"):
            q = float(r["qmph_median"]) if r["qmph_median"] else None
            cells[(r["engine"], r["workload"], r["scale"], int(r["clients"]))] = (q, r["status"])
    return cells


def fmt(v):
    if v >= 1e6:
        return f"{v / 1e6:.2f}M"
    if v >= 1e4:
        return f"{v / 1e3:.0f}k"
    if v >= 1e3:
        return f"{v / 1e3:.1f}k"
    return f"{v:.0f}"


def tick_label(v):
    if v == 0:
        return "0"
    for div, suffix in ((1e6, "M"), (1e3, "k")):
        if v >= div:
            return f"{v / div:g}{suffix}"
    return f"{v:g}"


def spread(ys, gap, lo, hi):
    """Push label y positions apart by at least `gap`, keeping order and staying in [lo, hi]."""
    order = sorted(range(len(ys)), key=lambda i: ys[i])
    placed, last = {}, -1e9
    for i in order:
        placed[i] = max(ys[i], last + gap)
        last = placed[i]
    overflow = last - hi
    if overflow > 0:
        for i in placed:
            placed[i] -= overflow
    first = min(placed.values()) if placed else lo
    if first < lo:
        for i in placed:
            placed[i] += lo - first
    return [placed[i] for i in range(len(ys))]


class Axis:
    def __init__(self, kind, lo, hi, ticks):
        self.kind, self.lo, self.hi, self.ticks = kind, lo, hi, ticks

    def frac(self, v):
        if self.kind == "log":
            return (math.log10(v) - math.log10(self.lo)) / (math.log10(self.hi) - math.log10(self.lo))
        return (v - self.lo) / (self.hi - self.lo)


def log_axis(values):
    lo = 10 ** math.floor(math.log10(min(values)))
    hi = 10 ** math.ceil(math.log10(max(values)))
    ticks, t = [], lo
    while t <= hi * 1.0001:
        ticks.append(t)
        t *= 10
    return Axis("log", lo, hi, ticks)


def linear_axis(values):
    top = max(values) * 1.08
    for step in (1, 2, 2.5, 5, 10, 20, 25, 50):
        mag = 10 ** math.floor(math.log10(top))
        s = step * mag / 10
        hi = math.ceil(top / s) * s
        if hi / s <= 6:
            return Axis("linear", 0, hi, [i * s for i in range(int(round(hi / s)) + 1)])
    return Axis("linear", 0, top, [0, top])


def marker_kinds(cells, workload, scales, engines):
    kinds = set()
    for (e, w, sc, _), (q, status) in cells.items():
        if w == workload and sc in scales and e in engines:
            if q is None:
                kinds.add("cross")
            elif status != "accepted":
                kinds.add("flagged")
    return kinds


def header(s, width, title, subtitle, axis_note, engines, left, kinds):
    s.append(f"<text x='{left}' y='28' font-size='17' font-weight='700' fill='{INK}'>{title}</text>")
    s.append(f"<text x='{left}' y='47' font-size='12' fill='{MUTED}'>{subtitle}</text>")
    s.append(f"<text x='{left}' y='70' font-size='13' font-weight='700' fill='{INK}'>"
             f"HIGHER IS FASTER · {axis_note}</text>")
    x = left
    y = 94
    for e in engines:
        name, col = ENGINES[e]
        w = 3.2 if e == "fluree" else 2
        s.append(f"<line x1='{x}' y1='{y - 4}' x2='{x + 18}' y2='{y - 4}' stroke='{col}' stroke-width='{w}'/>")
        s.append(f"<text x='{x + 24}' y='{y}' font-size='12' font-weight='{700 if e == 'fluree' else 400}' "
                 f"fill='{col}'>{name}</text>")
        x += 24 + len(name) * 7.2 + 22
    x += 8
    s.append(f"<circle cx='{x + 4}' cy='{y - 4}' r='3.6' fill='{MUTED}'/>")
    s.append(f"<text x='{x + 13}' y='{y}' font-size='11' fill='{MUTED}'>validated</text>")
    x += 13 + 9 * 6.1 + 18
    if "flagged" in kinds:
        s.append(f"<line x1='{x - 6}' y1='{y - 4}' x2='{x + 14}' y2='{y - 4}' stroke='{MUTED}' "
                 f"stroke-width='1.6' stroke-dasharray='4 3'/>")
        s.append(f"<circle cx='{x + 4}' cy='{y - 4}' r='3.8' fill='white' stroke='{MUTED}' stroke-width='1.8'/>")
        s.append(f"<text x='{x + 20}' y='{y}' font-size='11' fill='{MUTED}'>failed a repeat check</text>")
        x += 20 + 21 * 6.1 + 18
    if "cross" in kinds:
        s.append(cross(x + 4, y - 4, MUTED))
        s.append(f"<text x='{x + 13}' y='{y}' font-size='11' fill='{MUTED}'>run errored, no median</text>")


def cross(cx, cy, col, r=4.5):
    return (f"<path d='M{cx - r:.1f} {cy - r:.1f} L{cx + r:.1f} {cy + r:.1f} M{cx + r:.1f} {cy - r:.1f} "
            f"L{cx - r:.1f} {cy + r:.1f}' stroke='{col}' stroke-width='2.2' fill='none'/>")


def panel(s, cells, workload, scale, engines, clients, axis, px, py, pw, ph,
          title=None, subtitle=None, names_at_end=False, label_width=80):
    def x(i):
        return px + pw * i / (len(clients) - 1)

    def y(v):
        return py + ph * (1 - axis.frac(v))

    if title:
        s.append(f"<text x='{px}' y='{py - 14}' font-size='14' font-weight='700' fill='{INK}'>{title}</text>")
        s.append(f"<text x='{px + len(title) * 9 + 8}' y='{py - 14}' font-size='11' fill='{MUTED}'>{subtitle}</text>")
    for t in axis.ticks:
        yy = y(t)
        s.append(f"<line x1='{px}' y1='{yy:.1f}' x2='{px + pw}' y2='{yy:.1f}' stroke='{GRID}'/>")
        s.append(f"<text x='{px - 7}' y='{yy + 4:.1f}' font-size='10.5' fill='{MUTED}' text-anchor='end'>"
                 f"{tick_label(t)}</text>")
    s.append(f"<line x1='{px}' y1='{py + ph}' x2='{px + pw}' y2='{py + ph}' stroke='{MUTED}' stroke-opacity='0.5'/>")
    for i, c in enumerate(clients):
        s.append(f"<text x='{x(i):.1f}' y='{py + ph + 17}' font-size='10.5' fill='{MUTED}' "
                 f"text-anchor='middle'>{c}</text>")
    s.append(f"<text x='{px + pw / 2:.1f}' y='{py + ph + 35}' font-size='11' fill='{INK}' "
             f"text-anchor='middle'>concurrent clients</text>")

    ends = []
    for e in sorted(engines, key=lambda e: e == "fluree"):  # Fluree drawn last, on top
        _, col = ENGINES[e]
        pts = {c: cells[(e, workload, scale, c)] for c in clients if (e, workload, scale, c) in cells}
        width = 3.2 if e == "fluree" else 2
        for i in range(len(clients) - 1):
            a, b = pts.get(clients[i]), pts.get(clients[i + 1])
            if not a or not b or a[0] is None or b[0] is None:
                continue
            dash = "" if a[1] == "accepted" and b[1] == "accepted" else " stroke-dasharray='5 4'"
            s.append(f"<line x1='{x(i):.1f}' y1='{y(a[0]):.1f}' x2='{x(i + 1):.1f}' y2='{y(b[0]):.1f}' "
                     f"stroke='{col}' stroke-width='{width}'{dash}/>")
        last = None
        for i, c in enumerate(clients):
            if c not in pts:
                continue
            q, status = pts[c]
            if q is None:
                s.append(cross(x(i), py + ph, col))
            elif status == "accepted":
                s.append(f"<circle cx='{x(i):.1f}' cy='{y(q):.1f}' r='3.6' fill='{col}'/>")
                last = (c, q)
            else:
                s.append(f"<circle cx='{x(i):.1f}' cy='{y(q):.1f}' r='3.8' fill='white' stroke='{col}' "
                         f"stroke-width='1.8'/>")
                last = (c, q)
        if last:
            ends.append((e, last))

    order = sorted(ends, key=lambda t: list(ENGINES).index(t[0]))
    ys = spread([y(q) for _, (_, q) in order], 30 if names_at_end else 26, py + 4, py + ph)
    for (e, (c, q)), ly in zip(order, ys):
        name, col = ENGINES[e]
        weight = 700 if e == "fluree" else 400
        if names_at_end:
            s.append(f"<text x='{px + pw + 12}' y='{ly + 4:.1f}' font-size='12' font-weight='{weight}' "
                     f"fill='{col}'>{name}</text>")
            s.append(f"<text x='{px + pw + 12}' y='{ly + 18:.1f}' font-size='10' fill='{MUTED}'>"
                     f"{q:,.0f} QMpH @{c}</text>")
        else:
            s.append(f"<text x='{px + pw + 10}' y='{ly + 4:.1f}' font-size='12' font-weight='{weight}' "
                     f"fill='{col}'>{fmt(q)}</text>")
            s.append(f"<text x='{px + pw + 10 + len(fmt(q)) * 7.2 + 4:.1f}' y='{ly + 4:.1f}' font-size='10' "
                     f"fill='{MUTED}'>@{c}</text>")


def notes(s, lines, left, bottom):
    for i, line in enumerate(reversed(lines)):
        s.append(f"<text x='{left}' y='{bottom - i * 15}' font-size='11' fill='{MUTED}'>{line}</text>")


def write(name, s):
    s.append("</svg>")
    path = os.path.join(ASSETS, name)
    os.makedirs(ASSETS, exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(s))
    print("wrote", os.path.relpath(path))


def three_scales(cells, workload, engines, fname, title, subtitle, note_lines):
    clients_by_scale = {}
    axis_by_scale = {}
    for sc in SCALES:
        cs = sorted({c for (e, w, scl, c) in cells if w == workload and scl == sc and e in engines})
        clients_by_scale[sc] = cs
        axis_by_scale[sc] = linear_axis([cells[(e, workload, sc, c)][0] for e in engines for c in cs
                                         if (e, workload, sc, c) in cells
                                         and cells[(e, workload, sc, c)][0] is not None])
    W, H = 1120, 520
    slot = (W - 40) / 3
    py, ph = 146, 270
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' viewBox='0 0 {W} {H}' {FONT}>",
         f"<rect width='{W}' height='{H}' fill='white'/>"]
    header(s, W, title, subtitle, "QMpH (query mixes per hour) · each panel has its own scale", engines, 66,
           marker_kinds(cells, workload, SCALES, engines))
    for k, sc in enumerate(SCALES):
        px = 20 + k * slot + 46
        label, sub = SCALES[sc]
        panel(s, cells, workload, sc, engines, clients_by_scale[sc], axis_by_scale[sc], px, py,
              slot - 46 - 84, ph, title=label, subtitle=sub)
    notes(s, note_lines, 66, H - 14)
    write(fname, s)


def one_scale(cells, workload, scale, engines, kind, fname, title, subtitle, note_lines):
    clients = sorted({c for (e, w, scl, c) in cells if w == workload and scl == scale and e in engines})
    values = [cells[(e, workload, scale, c)][0] for e in engines for c in clients
              if (e, workload, scale, c) in cells and cells[(e, workload, scale, c)][0] is not None]
    axis = log_axis(values) if kind == "log" else linear_axis(values)
    lines = [HOSTS] + note_lines
    W, H = 820, 470 + 15 * len(lines)
    ML, MR, MT, MB = 70, 190, 130, 58 + 15 * len(lines)
    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' viewBox='0 0 {W} {H}' {FONT}>",
         f"<rect width='{W}' height='{H}' fill='white'/>"]
    note = "QMpH (query mixes per hour)" + (", log scale" if kind == "log" else "")
    header(s, W, title, subtitle, note, engines, ML, marker_kinds(cells, workload, [scale], engines))
    panel(s, cells, workload, scale, engines, clients, axis, ML, MT, W - ML - MR, H - MT - MB,
          names_at_end=True)
    notes(s, lines, ML, H - 12)
    write(fname, s)


def main():
    cells = load()
    three_scales(
        cells, "explore-select", ["fluree", "qlever", "virtuoso"], "bsbm-select-scaling.svg",
        "BSBM Explore, SELECT subset · throughput vs concurrent clients",
        f"Explore mix without the DESCRIBE/CONSTRUCT queries (Q9, Q12), 20 executions per mix · {HOSTS}",
        ["QLever's 128-client cells were run because its c64 beat c32 by more than 5%; Fluree's and Virtuoso's c64 did not."])
    three_scales(
        cells, "explore", ["fluree", "virtuoso"], "bsbm-explore-virtuoso-scaling.svg",
        "BSBM Explore, full mix · throughput vs concurrent clients",
        f"25-query Explore mix (11 templates) · {HOSTS}",
        ["QLever not shown: the full mix requires RDF/XML DESCRIBE/CONSTRUCT responses, which QLever 0.6.0 does not "
         "return to the driver."])
    one_scale(
        cells, "bi", "1m", ["fluree", "qlever"], "linear", "bsbm-bi-1m-scaling.svg",
        "BSBM Business Intelligence, 1M · throughput vs concurrent clients",
        "15-query BI mix (8 aggregate templates)",
        ["Virtuoso not shown: its BI Q5 returns an empty result, so its BI throughput is not a valid measurement.",
         "At 100M and 200M QLever completed only 1 client (41 and 34 QMpH); its 4–32 client cells failed repeatedly."])
    one_scale(
        cells, "update", "1m", ["fluree", "virtuoso"], "linear", "bsbm-update-1m-scaling.svg",
        "BSBM Explore-and-Update, 1M · throughput vs concurrent clients",
        "30-operation mix with 5 SPARQL Updates, every write fsynced before acknowledgement",
        ["QLever not shown: durable (fsync-before-acknowledgement) Update has not been established for QLever 0.6.0."])


if __name__ == "__main__":
    main()
