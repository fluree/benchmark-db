#!/usr/bin/env python3
"""Parse BSBM test-driver result XMLs into report inputs.

The driver (bsbmtools-0.2) writes one `benchmark_result.xml` per run with this
shape (verified against a real Fluree run, 2026-06-03):

    <bsbm>
      <querymix>
        <scalefactor/> <warmups/> <seed/> <querymixruns/>
        <minquerymixruntime/> <maxquerymixruntime/> <totalruntime/>
        <qmph/> <cqet/> <cqetg/>          # qmph = query mixes/hour; cqet = mix time (s)
      </querymix>
      <queries>
        <query nr="N">
          <executecount/> <aqet/> <aqetg/> <qps/>
          <minqet/> <maxqet/> <avgresults/> <minresults/> <maxresults/> <timeoutcount/>
        </query>  # note: dropped queries (e.g. explore Q6) have executecount 0
      </queries>
    </bsbm>

Usage:
    parse_bsbm_xml.py <result.xml> [<result.xml> ...]
    parse_bsbm_xml.py reports/bsbm-1m/runs/*.xml

For each input it derives a cell label from the filename (run-matrix.sh names
them `<usecase>__c<clients>__<cache>.xml`). Writes two TSVs next to the FIRST
input's directory and prints a summary table:

    querymix_summary.tsv   one row per cell: qmph, cqet, totalruntime, timeouts
    per_query.tsv          one row per (cell, query): aqet, qps, avgresults, timeouts
"""
import sys
import os
import re
import xml.etree.ElementTree as ET


def _txt(node, tag, default=""):
    el = node.find(tag)
    return el.text.strip() if el is not None and el.text else default


def cell_label(path):
    """`explore__c8__warm.xml` -> (explore, 8, warm); `explore__c8.xml` ->
    (explore, 8, ""). Falls back to the stem."""
    stem = os.path.splitext(os.path.basename(path))[0]
    m = re.match(r"(?P<uc>[^_]+)__c(?P<clients>\w+)(?:__(?P<cache>\w+))?$", stem)
    if m:
        return m.group("uc"), m.group("clients"), m.group("cache") or "", stem
    return stem, "", "", stem


def parse(path):
    root = ET.parse(path).getroot()
    qm = root.find("querymix")
    uc, clients, cache, stem = cell_label(path)
    summary = {
        "cell": stem, "usecase": uc, "clients": clients or "1", "cache": cache,
        "scalefactor": _txt(qm, "scalefactor"),
        "querymixruns": _txt(qm, "querymixruns"),
        "warmups": _txt(qm, "warmups"),
        "qmph": _txt(qm, "qmph"),
        "cqet_s": _txt(qm, "cqet"),
        "cqetg_s": _txt(qm, "cqetg"),
        "totalruntime_s": _txt(qm, "totalruntime"),
    }
    per_query = []
    timeouts = 0
    for q in root.findall("queries/query"):
        ec = int(_txt(q, "executecount", "0") or 0)
        if ec == 0:
            continue  # dropped from the mix (e.g. explore Q6)
        to = int(_txt(q, "timeoutcount", "0") or 0)
        timeouts += to
        per_query.append({
            "cell": stem, "usecase": uc, "clients": clients or "1", "cache": cache,
            "query": q.get("nr"),
            "executecount": ec,
            "aqet_s": _txt(q, "aqet"),
            "aqetg_s": _txt(q, "aqetg"),
            "qps": _txt(q, "qps"),
            "minqet_s": _txt(q, "minqet"),
            "maxqet_s": _txt(q, "maxqet"),
            "avgresults": _txt(q, "avgresults"),
            "timeoutcount": to,
        })
    summary["timeouts"] = timeouts
    return summary, per_query


def write_tsv(path, rows, cols):
    with open(path, "w") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r.get(c, "")) for c in cols) + "\n")


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    summaries, per_query = [], []
    for p in argv:
        try:
            s, pq = parse(p)
        except Exception as e:  # noqa: BLE001 — surface the bad file, keep going
            print(f"WARN: failed to parse {p}: {e}", file=sys.stderr)
            continue
        summaries.append(s)
        per_query.extend(pq)

    if not summaries:
        print("No parseable result XMLs.", file=sys.stderr)
        return 1

    out_dir = os.path.dirname(os.path.abspath(argv[0]))
    sum_cols = ["cell", "usecase", "clients", "cache", "scalefactor",
                "querymixruns", "warmups", "qmph", "cqet_s", "cqetg_s",
                "totalruntime_s", "timeouts"]
    pq_cols = ["cell", "usecase", "clients", "cache", "query", "executecount",
               "aqet_s", "aqetg_s", "qps", "minqet_s", "maxqet_s",
               "avgresults", "timeoutcount"]
    sum_path = os.path.join(out_dir, "querymix_summary.tsv")
    pq_path = os.path.join(out_dir, "per_query.tsv")
    write_tsv(sum_path, summaries, sum_cols)
    write_tsv(pq_path, per_query, pq_cols)

    # Console summary (QMpH is the BSBM headline; higher = faster).
    print(f"{'cell':32} {'QMpH':>10} {'mix(s)':>8} {'runs':>5} {'timeouts':>8}")
    print("-" * 70)
    for s in sorted(summaries, key=lambda r: (r["usecase"], r["clients"], r["cache"])):
        print(f"{s['cell']:32} {s['qmph']:>10} {s['cqet_s']:>8} "
              f"{s['querymixruns']:>5} {s['timeouts']:>8}")
    print(f"\nWrote: {sum_path}\n       {pq_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
