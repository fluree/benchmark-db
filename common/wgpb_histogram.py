#!/usr/bin/env python3
"""
Bucket WGPB per-query median times into the latency histogram the WGPB
competitors report (Stardog, AllegroGraph): <100ms, 100-500ms, 500ms-1s,
1s-2s, 2s-5s, >5s. Also reports any timeouts/errors separately (honest:
the competitor charts assume all 850 queries return).

  python3 common/wgpb_histogram.py <summary.tsv> [--title T] [--svg out.svg]

Input is a *_summary.tsv produced by common/summarize.py
(columns: query_id, description, status, median_ms, ...).
"""
import argparse
import csv
import os

# (label, lo_ms_inclusive, hi_ms_exclusive)  -- hi=None means open-ended
BUCKETS = [
    ("< 100 ms", 0, 100),
    ("100 ms – 500 ms", 100, 500),
    ("500 ms – 1 s", 500, 1000),
    ("1 s – 2 s", 1000, 2000),
    ("2 s – 5 s", 2000, 5000),
    ("> 5 s", 5000, None),
]

FLUREE = "#0d9488"
INK = "#1e293b"
MUTED = "#64748b"
GRID = "#e2e8f0"
FONT = "font-family='-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif'"


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def load(path):
    oks, fails = [], 0
    with open(path) as f:
        for row in csv.DictReader(f, delimiter="\t"):
            if row["status"] == "200" and row["median_ms"] not in ("", None):
                oks.append(float(row["median_ms"]))
            else:
                fails += 1
    return oks, fails


def bucketize(times):
    counts = [0] * len(BUCKETS)
    for t in times:
        for i, (_, lo, hi) in enumerate(BUCKETS):
            if t >= lo and (hi is None or t < hi):
                counts[i] += 1
                break
    return counts


def svg(counts, total, title, fails):
    labels = [b[0] for b in BUCKETS]
    n = len(BUCKETS)
    W, H = 880, 460
    L, R, T, B = 70, 30, 70, 90
    pw, ph = W - L - R, H - T - B
    ymax = max(max(counts), 1)
    # round ymax up to a nice gridline
    import math
    step = 10 ** (len(str(ymax)) - 1)
    ytop = math.ceil(ymax / step) * step
    slot = pw / n
    bw = slot * 0.62

    def y(v):
        return T + ph - (v / ytop) * ph

    s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
         f"viewBox='0 0 {W} {H}' {FONT}>"]
    s.append(f"<rect width='{W}' height='{H}' fill='white'/>")
    s.append(f"<text x='20' y='28' font-size='18' font-weight='700' fill='{INK}'>"
             f"{esc(title)}</text>")
    sub = f"{total} queries · per-query median of 3 runs · lower is better"
    if fails:
        sub += f" · {fails} timeout/error"
    s.append(f"<text x='20' y='48' font-size='12.5' fill='{MUTED}'>{esc(sub)}</text>")
    # y gridlines
    nticks = 5
    for k in range(nticks + 1):
        gv = ytop * k / nticks
        gy = y(gv)
        s.append(f"<line x1='{L}' y1='{gy:.1f}' x2='{W-R}' y2='{gy:.1f}' "
                 f"stroke='{GRID}' stroke-width='1'/>")
        s.append(f"<text x='{L-8}' y='{gy+4:.1f}' font-size='11' fill='{MUTED}' "
                 f"text-anchor='end'>{int(gv)}</text>")
    s.append(f"<text x='18' y='{T-16}' font-size='11.5' fill='{MUTED}'>Number of queries</text>")
    for i, (lab, c) in enumerate(zip(labels, counts)):
        cx = L + i * slot + slot / 2
        bx = cx - bw / 2
        by = y(c)
        s.append(f"<rect x='{bx:.1f}' y='{by:.1f}' width='{bw:.1f}' "
                 f"height='{T+ph-by:.1f}' rx='3' fill='{FLUREE}'/>")
        pct = 100.0 * c / total if total else 0
        s.append(f"<text x='{cx:.1f}' y='{by-20:.1f}' font-size='13' font-weight='700' "
                 f"fill='{INK}' text-anchor='middle'>{c}</text>")
        s.append(f"<text x='{cx:.1f}' y='{by-6:.1f}' font-size='10.5' "
                 f"fill='{MUTED}' text-anchor='middle'>{pct:.1f}%</text>")
        s.append(f"<text x='{cx:.1f}' y='{H-B+22:.1f}' font-size='11.5' fill='{INK}' "
                 f"text-anchor='middle'>{esc(lab)}</text>")
    s.append(f"<text x='{L+pw/2:.1f}' y='{H-18}' font-size='12' fill='{INK}' "
             f"text-anchor='middle' font-weight='600'>Query Execution Time</text>")
    s.append("</svg>")
    return "\n".join(s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("summary")
    ap.add_argument("--title", default="Wikidata Graph Pattern Benchmark (WGPB) — Fluree")
    ap.add_argument("--svg", default=None)
    args = ap.parse_args()

    times, fails = load(args.summary)
    total = len(times) + fails
    counts = bucketize(times)

    print(f"{'bucket':<18} {'count':>6} {'pct':>7}  cumulative")
    cum = 0
    for (lab, _, _), c in zip(BUCKETS, counts):
        cum += c
        print(f"{lab:<18} {c:>6} {100*c/total:>6.1f}%  {100*cum/total:>6.1f}%")
    if fails:
        print(f"{'timeout/error':<18} {fails:>6} {100*fails/total:>6.1f}%")
    print(f"{'TOTAL':<18} {total:>6}")
    if times:
        st = sorted(times)
        import math
        geo = math.exp(sum(math.log(max(t, 1)) for t in st) / len(st))
        print(f"\nmedian={st[len(st)//2]:.0f}ms  geo-mean={geo:.0f}ms  "
              f"max={st[-1]:.0f}ms  <100ms={100*counts[0]/total:.1f}%  "
              f"<1s={100*sum(counts[:3])/total:.1f}%")

    if args.svg:
        os.makedirs(os.path.dirname(os.path.abspath(args.svg)), exist_ok=True)
        with open(args.svg, "w") as f:
            f.write(svg(counts, total, args.title, fails))
        print(f"\nwrote {args.svg}")


if __name__ == "__main__":
    main()
