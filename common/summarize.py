#!/usr/bin/env python3
"""
Summarize or diff SPARQLoscope benchmark results.

Summarize a per-run TSV into one row per query:
    python3 summarize.py <results.tsv>
    # -> query_id, description, status, median_ms, min_ms, max_ms, result_size, error

Diff a new summary against a baseline summary (e.g. the published reference):
    python3 summarize.py --diff <baseline_summary.tsv> <new_summary.tsv>
    # -> per-query median delta + aggregate arithmetic-mean change
"""

import csv
import sys
from collections import defaultdict


def median(values):
    s = sorted(values)
    n = len(s)
    if n == 0:
        return 0
    if n % 2 == 1:
        return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2]) / 2


def summarize(input_file):
    queries = defaultdict(
        lambda: {"description": "", "times": [], "statuses": [], "sizes": [], "errors": []}
    )

    with open(input_file) as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            qid = row["query_id"]
            queries[qid]["description"] = row.get("description", "")
            queries[qid]["times"].append(float(row["time_ms"]))
            queries[qid]["statuses"].append(row["status"])
            queries[qid]["sizes"].append(row.get("result_size", ""))
            queries[qid]["errors"].append(row.get("error", ""))

    print("query_id\tdescription\tstatus\tmedian_ms\tmin_ms\tmax_ms\tresult_size\terror")
    for qid, data in sorted(queries.items()):
        times = data["times"]
        statuses = data["statuses"]
        status = max(set(statuses), key=statuses.count)
        med = median(times)
        mn = min(times)
        mx = max(times)
        size = data["sizes"][-1] if data["sizes"] else ""
        error = next((e for e in data["errors"] if e), "")
        print(f"{qid}\t{data['description']}\t{status}\t{med}\t{mn}\t{mx}\t{size}\t{error}")


def load_summary(path):
    out = {}
    with open(path) as f:
        for row in csv.DictReader(f, delimiter="\t"):
            out[row["query_id"]] = row
    return out


def diff(baseline_file, new_file):
    base = load_summary(baseline_file)
    new = load_summary(new_file)

    print(f"{'query_id':<48}{'baseline':>12}{'new':>12}{'delta':>12}{'change':>10}")
    print("-" * 94)

    base_ok, new_ok = [], []
    for qid in sorted(set(base) | set(new)):
        b = base.get(qid)
        n = new.get(qid)
        b_ms = float(b["median_ms"]) if b and b["status"] == "200" else None
        n_ms = float(n["median_ms"]) if n and n["status"] == "200" else None
        if b_ms is not None:
            base_ok.append(b_ms)
        if n_ms is not None:
            new_ok.append(n_ms)

        b_s = f"{b_ms:,.0f}" if b_ms is not None else "FAIL/-"
        n_s = f"{n_ms:,.0f}" if n_ms is not None else "FAIL/-"
        if b_ms and n_ms:
            delta = n_ms - b_ms
            pct = (delta / b_ms * 100) if b_ms else 0
            mark = "  ^" if delta > 0 else ("  v" if delta < 0 else "  =")
            print(f"{qid:<48}{b_s:>12}{n_s:>12}{delta:>+12,.0f}{pct:>+8.0f}%{mark}")
        else:
            print(f"{qid:<48}{b_s:>12}{n_s:>12}{'-':>12}{'-':>10}")

    print("-" * 94)
    if base_ok and new_ok:
        b_mean = sum(base_ok) / len(base_ok)
        n_mean = sum(new_ok) / len(new_ok)
        d = n_mean - b_mean
        pct = (d / b_mean * 100) if b_mean else 0
        print(
            f"Arithmetic mean (passing): baseline {b_mean:,.1f} ms  ->  "
            f"new {n_mean:,.1f} ms  ({d:+,.1f} ms, {pct:+.0f}%)"
        )
        print(f"Passing queries: baseline {len(base_ok)}  ->  new {len(new_ok)}")


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    if args[0] == "--diff":
        if len(args) != 3:
            print("Usage: summarize.py --diff <baseline_summary.tsv> <new_summary.tsv>", file=sys.stderr)
            sys.exit(1)
        diff(args[1], args[2])
    else:
        summarize(args[0])


if __name__ == "__main__":
    main()
