#!/usr/bin/env python3
"""Build comparison.tsv: every BSBM cell measured under the v4.2.1 capacity protocol for
Fluree, QLever and Virtuoso, with its validation status. Reads the local run archives
(runs/ is not in git); comparison.tsv is the committed input for make_comparison_charts.py.

  python3 collect_comparison.py

Sources
  Fluree v4.2.1 (all workloads)         summary.tsv (this directory)
  QLever 0.6.0, Virtuoso 7.2.17        runs/bsbm-gap-closure-20260907/analysis.json, then
                                        runs/bsbm-capacity-refresh-20260907/analysis.json for
                                        cells the gap-closure run did not re-measure

status
  accepted   three repeats finished, result counts matched across repeats, spread <= 5%
  flagged    a median exists but a check failed (see detail)
  no-result  a repeat errored or the cell failed repeatedly, so there is no median
  invalid    measured, but the engine returns incorrect results for this workload
"""
import csv
import glob
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
RUNS = os.path.join(REPO, "runs")
OUT = os.path.join(HERE, "comparison.tsv")

VERSION = {"fluree": "v4.2.1", "qlever": "0.6.0", "virtuoso": "7.2.17"}
WORKLOAD = {"select": "explore-select", "explore": "explore", "bi": "bi", "update": "update"}
FIELDS = ["engine", "version", "scale", "workload", "clients", "qmph_median", "status", "detail", "source"]
SCALE_ORDER = {"1m": 0, "100m": 1, "200m": 2}
WORKLOAD_ORDER = {"explore": 0, "explore-select": 1, "bi": 2, "update": 3}
COMPETITOR_RUNS = ["bsbm-capacity-refresh-20260907", "bsbm-gap-closure-20260907"]  # later wins


def classify(cell):
    q = cell.get("qmph_median")
    if q is None:
        return "no-result", "a repeat errored; no median"
    if cell.get("accepted"):
        return "accepted", ""
    reasons = []
    if not cell.get("repeat_result_counts_match"):
        reasons.append("result counts differ between repeats")
    spread = cell.get("spread_percent")
    if spread is not None and spread > 5:
        reasons.append(f"spread {spread:.1f}%")
    return "flagged", "; ".join(reasons) or "failed acceptance checks"


def row(engine, scale, workload, clients, qmph, status, detail, source):
    return {"engine": engine, "version": VERSION[engine], "scale": scale, "workload": workload,
            "clients": int(clients), "qmph_median": "" if qmph is None else f"{qmph:.2f}",
            "status": status, "detail": detail, "source": source}


def fluree_rows():
    rows = []
    with open(os.path.join(HERE, "summary.tsv")) as f:
        for r in csv.DictReader(f, delimiter="\t"):
            timeouts = int(r["timeouts"])
            status = "accepted" if timeouts == 0 else "flagged"
            rows.append(row("fluree", r["scale"], WORKLOAD.get(r["workload"], r["workload"]), r["clients"],
                            float(r["qmph_median"]),
                            status, "" if timeouts == 0 else f"{timeouts} timeouts",
                            "benchmarks/bsbm/reports/v4.2.1/summary.tsv"))
    if sum(r["workload"] == "explore-select" for r in rows) != 18:
        raise SystemExit("expected 18 Fluree SELECT-subset cells in summary.tsv")
    return rows


def competitor_rows():
    cells = {}
    for run in COMPETITOR_RUNS:
        for cell in json.load(open(os.path.join(RUNS, run, "analysis.json"))):
            if cell.get("engine") not in ("qlever", "virtuoso"):
                continue
            workload = WORKLOAD[cell["workload"]]
            status, detail = classify(cell)
            if cell["engine"] == "virtuoso" and workload == "bi":
                status = "invalid"
                detail = "BI Q5 returns an empty result (incorrect); see reports/engine-comparison/BI-Q5-CORRECTNESS.md"
            key = (cell["engine"], cell["scale"], workload, int(cell["clients"]))
            cells[key] = row(cell["engine"], cell["scale"], workload, cell["clients"], cell.get("qmph_median"),
                             status, detail, f"runs/{run}/{cell.get('source', 'analysis.json')}")
        # cells that failed repeatedly never reach analysis.json; record them as no-result
        for path in glob.glob(os.path.join(RUNS, run, "*-generator", "live", "failure-*.json")):
            failure = json.load(open(path))
            original = failure.get("original", {})
            engine = original.get("engine")
            if engine not in ("qlever", "virtuoso"):
                continue
            key = (engine, original["scale"], WORKLOAD[original["workload"]], int(original["clients"]))
            if key in cells and cells[key]["qmph_median"]:
                continue
            cells[key] = row(engine, original["scale"], WORKLOAD[original["workload"]], original["clients"],
                             None, "no-result", f"{failure.get('status', 'failure')} after restart",
                             os.path.relpath(path, REPO))
    return list(cells.values())


def main():
    rows = fluree_rows() + competitor_rows()
    rows.sort(key=lambda r: (WORKLOAD_ORDER[r["workload"]], SCALE_ORDER[r["scale"]], r["engine"], r["clients"]))
    with open(OUT, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    counts = {}
    for r in rows:
        counts[(r["engine"], r["status"])] = counts.get((r["engine"], r["status"]), 0) + 1
    print("wrote", os.path.relpath(OUT, REPO), len(rows), "cells", dict(sorted(counts.items())))


if __name__ == "__main__":
    main()
