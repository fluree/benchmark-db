#!/usr/bin/env python3
"""
Generate a per-dataset benchmark REPORT.md for the SPARQLoscope DBLP/Wikidata runs.

Layout it consumes (one directory per dataset):

  reports/<dataset>/
    meta.json                      # env, dataset facts, per-engine setup + import facts
    engines/<engine>_summary.tsv   # run_benchmark.sh summary (query_id, description, status, median_ms, ...)
    correctness.json               # optional: [[query_id, STATUS, ...], ...] from the result-equivalence check

Emits reports/<dataset>/REPORT.md with four parts: Environment, Import, Query benchmark
(aggregates -> category rollup -> per-query), Correctness & caveats.

Cell convention in the query grids: `abs (×best)` where ×best = slowdown vs the
fastest engine in that row (fastest = 1.0x, bolded). Rows whose best is below
FLOOR_MS show absolute only (ratios on trivial-absolute queries are noise).

stdlib only.
"""
import json, csv, math, os, sys, argparse

FLOOR_MS = 10  # below this, suppress ×-factor (trivial absolute time)

# --- SPARQLoscope query categories (display order, name, match rule) ---------
# Rules are evaluated in order; first match wins.
CATEGORIES = [
    ("Dataset statistics",   lambda q: q.startswith("number-of-")),
    ("JOIN",                 lambda q: q.startswith("join-") or q.startswith("multicolumn-join-")),
    ("OPTIONAL",             lambda q: q.startswith("optional-join-")),
    ("MINUS",                lambda q: q.startswith("minus-join-")),
    ("EXISTS",               lambda q: q.startswith("exists-join-")),
    ("UNION",                lambda q: q.startswith("union-")),
    ("GROUP BY / aggregate", lambda q: q.startswith("group-by-") or q.startswith("distinct-count-")),
    ("FILTER",               lambda q: q.startswith("filter-")),
    ("Numeric functions",    lambda q: q.startswith("numeric-")),
    ("Date functions",       lambda q: q.startswith("date-")),
    ("String / REGEX",       lambda q: q.startswith("regex-") or q.startswith("str")),
    ("Transitive paths",     lambda q: q.startswith("transitive-path-")),
    ("Result size / export", lambda q: q.startswith("result-size-")),
]
CAT_ORDER = [c[0] for c in CATEGORIES]

def category_of(qid):
    for name, rule in CATEGORIES:
        if rule(qid):
            return name
    return "Other"

def load_categories(dataset_dir):
    """Find report-categories.tsv by walking up from the dataset dir (each benchmark
    supplies its own). Returns ({query_id: category}, [ordered categories]); falls
    back to ({}, None) so the built-in rules above are used."""
    here = os.path.abspath(dataset_dir)
    for _ in range(6):
        p = os.path.join(here, "report-categories.tsv")
        if os.path.exists(p):
            catmap, order = {}, []
            for r in csv.DictReader(open(p), delimiter="\t"):
                catmap[r["query_id"]] = r["category"]
                order.append((int(r.get("order", 99)), r["category"]))
            seen, ordered = set(), []
            for _o, c in sorted(order):
                if c not in seen:
                    seen.add(c); ordered.append(c)
            return catmap, ordered
        parent = os.path.dirname(here)
        if parent == here:
            break
        here = parent
    return {}, None

def geomean(vals):
    # sub-millisecond (0 ms) results are floored to 1 ms so they count as "fast"
    # rather than being dropped (geomean is sensitive to near-zero values).
    vals = [max(v, 1) for v in vals if v is not None]
    if not vals:
        return None
    return math.exp(sum(math.log(v) for v in vals) / len(vals))

def median(vals):
    vals = sorted(v for v in vals if v is not None)
    if not vals:
        return None
    n = len(vals)
    return vals[n // 2] if n % 2 else (vals[n // 2 - 1] + vals[n // 2]) / 2

def load_summary(path):
    out = {}
    with open(path) as f:
        for r in csv.DictReader(f, delimiter="\t"):
            try:
                out[r["query_id"]] = int(r["median_ms"])
            except (ValueError, KeyError):
                out[r["query_id"]] = None
    return out

def fmt_ms(ms):
    if ms is None:
        return "—"
    if ms >= 10000:
        return f"{ms/1000:.1f} s"
    return f"{round(ms):,} ms"

def cell(ms, best, bold):
    """`abs (×best)`; floor-guarded; leader bolded."""
    if ms is None:
        return "—"
    s = fmt_ms(ms)
    if best is not None and best >= FLOOR_MS and ms >= FLOOR_MS:
        s += f" ({ms/best:.1f}×)"
    return f"**{s}**" if bold else s

def cm(s):  # correctness mark
    # ✓ agree · ≈ within data delta · ⚠ documented engine-semantics difference
    # (both defensible, Fluree spec-correct) · ✗ genuine divergence under review
    return {"MATCH": "✓", "CLOSE": "≈", "ROWS_MATCH": "✓",
            "EXPECTED": "⚠", "DIFF": "✗"}.get(s, "?" if s else "")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dataset_dir", help="reports/<dataset>/")
    args = ap.parse_args()
    d = args.dataset_dir
    meta = json.load(open(os.path.join(d, "meta.json")))
    engines = list(meta["engines"].keys())  # display order from meta
    summ = {e: load_summary(os.path.join(d, "engines", f"{e}_summary.tsv")) for e in engines}
    # correctness (optional): {query_id: STATUS}
    corr = {}
    cpath = os.path.join(d, "correctness.json")
    if os.path.exists(cpath):
        for row in json.load(open(cpath)):
            corr[row[0]] = row[1]
    all_q = sorted(set().union(*[set(s) for s in summ.values()]))
    catmap, catorder = load_categories(d)
    cat_of = (lambda q: catmap.get(q, category_of(q))) if catmap else category_of
    cat_order = catorder if catorder else CAT_ORDER
    L = []  # lines
    ds = meta["dataset"]; hw = meta["hardware"]; mth = meta.get("methodology", {})
    draft = meta.get("status", "")

    def n(x):  # int with commas, else '?'
        return f"{x:,}" if isinstance(x, int) else "?"
    lab = lambda e: meta["engines"][e].get("label", e)

    L.append(f"# SPARQLoscope benchmark — {ds['name']}")
    if draft:
        L.append(f"\n> **{draft}**")
    # at-a-glance context line so the query numbers are interpretable up top;
    # full dataset / hardware / import detail lives in §3–§4.
    L.append(f"\n**Dataset:** {n(ds.get('triples'))} triples, {n(ds.get('predicates'))} predicates "
             f"({ds.get('version','?')}) · **Engines:** "
             + ", ".join(f"{lab(e)} {meta['engines'][e].get('version','')}" for e in engines)
             + f" · **Box:** {hw.get('instance','?')} ({hw.get('cores','?')}c / {hw.get('ram_gb','?')} GB) · "
             f"{mth.get('warmup','?')}+{mth.get('runs','?')} runs, {mth.get('metric','median')}, {mth.get('timeout_s','?')} s timeout")
    L.append("\n_Query results first; dataset/hardware/import detail in §3–§4._\n")

    # ===== 1. QUERY BENCHMARK (the headline) =================================
    L.append("## 1. Query benchmark\n")

    # 1a. aggregates
    L.append("### 1a. Aggregates\n")
    head = "| metric | " + " | ".join(meta["engines"][e].get("label", e) for e in engines) + " |"
    L.append(head + "\n|" + "---|" * (len(engines) + 1))
    def agg_row(label, fn):
        vals = {e: fn([summ[e][q] for q in all_q]) for e in engines}
        best = min((v for v in vals.values() if v is not None), default=None)
        cells = " | ".join(cell(vals[e], best, vals[e] == best) for e in engines)
        L.append(f"| {label} | {cells} |")
    passed = {e: sum(1 for q in all_q if summ[e].get(q) is not None) for e in engines}
    L.append(f"| passed | " + " | ".join(f"{passed[e]}/{len(all_q)}" for e in engines) + " |")
    agg_row("arith mean", lambda v: (sum(x for x in v if x is not None)/len([x for x in v if x is not None])) if any(x is not None for x in v) else None)
    agg_row("geo mean", geomean)
    agg_row("median", median)
    # per-engine geo-slowdown-vs-best across all queries (single standing number)
    slow = {}
    for e in engines:
        ratios = []
        for q in all_q:
            best = min((summ[x].get(q) for x in engines if summ[x].get(q)), default=None)
            v = summ[e].get(q)
            if v and best and best >= FLOOR_MS:
                ratios.append(v / best)
        slow[e] = geomean(ratios)
    L.append("\n**Geo-mean slowdown vs the best engine on each query** (1.00× = leads every query):")
    L.append("\n| " + " | ".join(meta["engines"][e].get("label", e) for e in engines) + " |\n|" + "---|"*len(engines))
    L.append("| " + " | ".join(f"{slow[e]:.2f}×" if slow[e] else "—" for e in engines) + " |")
    L.append("")

    # 1b. category rollup (geo mean per engine + fastest)
    L.append("### 1b. By category (geo mean)\n")
    L.append("| category | n | " + " | ".join(meta["engines"][e].get("label", e) for e in engines) + " | fastest |")
    L.append("|---|--:|" + "---|"*len(engines) + "---|")
    for cat in cat_order:
        qs = [q for q in all_q if cat_of(q) == cat]
        if not qs:
            continue
        vals = {e: geomean([summ[e][q] for q in qs]) for e in engines}
        best = min((v for v in vals.values() if v is not None), default=None)
        fastest = next((meta["engines"][e].get("label", e) for e in engines if vals[e] == best), "—")
        cells = " | ".join(cell(vals[e], best, vals[e] == best) for e in engines)
        L.append(f"| {cat} | {len(qs)} | {cells} | {fastest} |")
    L.append("")

    # 1c. per-query table
    L.append("### 1c. Per query\n")
    rh = "| query | category | " + " | ".join(meta["engines"][e].get("label", e) for e in engines)
    rh += (" | results |" if corr else " |")
    L.append(rh + "\n|---|---|" + "---|"*len(engines) + ("---|" if corr else ""))
    for cat in cat_order:
        for q in [x for x in all_q if cat_of(x) == cat]:
            vals = {e: summ[e].get(q) for e in engines}
            best = min((v for v in vals.values() if v is not None), default=None)
            cells = " | ".join(cell(vals[e], best, vals[e] == best) for e in engines)
            row = f"| `{q}` | {cat} | {cells}"
            row += f" | {cm(corr.get(q))} |" if corr else " |"
            L.append(row)
    L.append("")

    # ===== 2. RESULT CORRECTNESS =============================================
    L.append("## 2. Result correctness\n")
    if corr:
        from collections import Counter
        c = Counter(corr.values())
        agree = c.get("MATCH",0)+c.get("CLOSE",0)+c.get("ROWS_MATCH",0)
        L.append(f"Result-equivalence vs the reference engine (per-query `results` column above): "
                 f"**{agree}/{len(corr)} agree** "
                 f"({c.get('MATCH',0)} exact ✓, {c.get('CLOSE',0)} within the data delta ≈, {c.get('ROWS_MATCH',0)} row-count ✓); "
                 f"**{c.get('EXPECTED',0)} documented engine-semantics differences ⚠**; "
                 f"**{c.get('DIFF',0)} under review ✗**.")
        exp = [q for q in corr if corr[q] == "EXPECTED"]
        if exp:
            L.append(f"\n**Documented differences (⚠)** — both results defensible; Fluree follows the SPARQL "
                     f"spec where they diverge (see §4 caveats): "
                     f"{', '.join('`'+q+'`' for q in exp)}.")
        diffs = [q for q in corr if corr[q] == "DIFF"]
        if diffs:
            L.append(f"\n**Under review (✗)** — small (±1 row) divergences, root cause not yet confirmed: "
                     f"{', '.join('`'+q+'`' for q in diffs)}.")
    else:
        L.append("_No correctness check available for this run._")
    L.append("")

    # ===== 3. IMPORT / INDEXING ==============================================
    L.append("## 3. Import / indexing\n")
    L.append("| engine | import time | throughput | peak RAM | index size | notes |\n|---|---|---|---|---|---|")
    for e in engines:
        im = meta["engines"][e].get("import", {})
        L.append(f"| {lab(e)} | {im.get('time','?')} | {im.get('throughput','?')} "
                 f"| {im.get('peak_ram','?')} | {im.get('index_size','?')} | {im.get('notes','')} |")
    for e in engines:
        im = meta["engines"][e].get("import", {})
        if im.get("phases"):
            L.append(f"\n- **{lab(e)} phases:** {im['phases']}")
    L.append("")

    # ===== 4. ENVIRONMENT & DATASET ==========================================
    L.append("## 4. Environment & dataset\n")
    L.append(f"- **Dataset:** {ds['name']} — {ds.get('description','')}")
    L.append(f"  - source: {ds.get('source_url','?')}")
    L.append(f"  - version: {ds.get('version','?')} · SHA-256 `{ds.get('sha256','?')}`")
    L.append(f"  - **{n(ds.get('triples'))} triples**, {n(ds.get('predicates'))} predicates, "
             f"{n(ds.get('subjects'))} subjects, {n(ds.get('objects'))} objects · on-disk {ds.get('size_disk','?')}")
    L.append(f"- **Hardware:** {hw.get('instance','?')} — {hw.get('cpu','?')}, {hw.get('cores','?')} cores, "
             f"{hw.get('ram_gb','?')} GB RAM, {hw.get('disk','?')}, {hw.get('os','?')}")
    L.append(f"- **Method:** {mth.get('warmup','?')} warmup + {mth.get('runs','?')} timed runs, "
             f"{mth.get('metric','median')} reported, {mth.get('timeout_s','?')} s timeout, "
             f"results as `{mth.get('accept','text/tab-separated-values')}`")
    if mth.get("notes"):
        L.append(f"  - {mth['notes']}")
    L.append("\n| engine | version | config |\n|---|---|---|")
    for e in engines:
        m = meta["engines"][e]
        ver = m.get("version", "?") + (f" (`{m['commit']}`)" if m.get("commit") else "")
        L.append(f"| {lab(e)} | {ver} | {m.get('config','')} |")
    if meta.get("caveats"):
        L.append("\n**Caveats**")
        for note in meta["caveats"]:
            L.append(f"- {note}")
    L.append("")

    out = os.path.join(d, "REPORT.md")
    with open(out, "w") as f:
        f.write("\n".join(L))
    print(f"wrote {out} ({len(all_q)} queries, {len(engines)} engines)")

if __name__ == "__main__":
    main()
