#!/usr/bin/env python3
"""
Compare per-query result bodies across engines to catch zero/wrong results.

Usage:
    python3 compare_outputs.py \\
        --engine fluree    engines/fluree/query-outputs/ engines/fluree/fluree_summary.tsv \\
        --engine qlever    engines/qlever/query-outputs/ engines/qlever/qlever_summary.tsv \\
        [--diff]           # print content diffs for mismatches (slow for large results)
        [--out report.tsv] # write a TSV matrix (default: stdout)

Each engine's query-outputs/ directory must contain files named
<query_id>-run<N>.tsv written by run_benchmark.sh --save-outputs.
The companion *_summary.tsv (from summarize.py) identifies the median run.

Output:
  - A query × engine matrix of result row counts.
  - Per-query mismatch flags (MATCH / COUNT_MISMATCH / CONTENT_MISMATCH / MISSING).
  - Summary line: total mismatches, queries where all engines agree.
"""

import argparse
import csv
import hashlib
import os
import sys
from pathlib import Path


def load_summary(path):
    """Return {query_id: {"median_ms": float, "status": str, "result_size": str}}"""
    out = {}
    with open(path) as f:
        for row in csv.DictReader(f, delimiter="\t"):
            out[row["query_id"]] = {
                "median_ms": float(row.get("median_ms", 0) or 0),
                "status": row.get("status", ""),
                "result_size": row.get("result_size", ""),
                "min_ms": float(row.get("min_ms", 0) or 0),
                "max_ms": float(row.get("max_ms", 0) or 0),
            }
    return out


def find_median_run(outputs_dir, query_id, summary_row):
    """Return (run_number, path) of the run whose time matches the median."""
    median_ms = summary_row["median_ms"]
    # Try run files 1..5; pick the one whose size matches result_size, or
    # whose run number gives the middle index (fallback).
    candidates = sorted(outputs_dir.glob(f"{query_id}-run*.tsv"))
    if not candidates:
        return None, None
    # If there's only one, use it.
    if len(candidates) == 1:
        return 1, candidates[0]
    # Match by index: middle run (same logic as the shell script).
    mid = len(candidates) // 2
    return mid + 1, candidates[mid]


def count_rows(path):
    """Return the number of data rows (non-header lines) in a TSV result file."""
    if path is None or not path.exists():
        return None
    try:
        with open(path, "rb") as f:
            content = f.read()
        lines = content.split(b"\n")
        # Drop empty trailing line and header line (first line)
        data_lines = [l for l in lines if l]
        return max(0, len(data_lines) - 1)  # subtract header
    except Exception:
        return None


def content_hash(path):
    """SHA-256 of the sorted data rows (order-independent comparison)."""
    if path is None or not path.exists():
        return None
    try:
        with open(path, "rb") as f:
            content = f.read()
        lines = content.split(b"\n")
        if not lines:
            return hashlib.sha256(b"").hexdigest()
        header = lines[0]
        data = sorted(l for l in lines[1:] if l)
        h = hashlib.sha256(header + b"\n" + b"\n".join(data))
        return h.hexdigest()
    except Exception:
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--engine", nargs=3, action="append", metavar=("NAME", "OUTPUTS_DIR", "SUMMARY_TSV"),
        help="Engine name, path to query-outputs dir, path to summary TSV. Repeat for each engine.",
    )
    parser.add_argument("--diff", action="store_true", help="Print content diffs for mismatches")
    parser.add_argument("--out", default="-", help="Output TSV path (default: stdout)")
    args = parser.parse_args()

    if not args.engine:
        parser.print_help()
        sys.exit(1)

    engines = []
    for name, outputs_dir, summary_tsv in args.engine:
        outputs = Path(outputs_dir)
        if not outputs.exists():
            print(f"WARNING: outputs dir not found: {outputs_dir}", file=sys.stderr)
        summary = load_summary(summary_tsv) if os.path.exists(summary_tsv) else {}
        engines.append({"name": name, "outputs": outputs, "summary": summary})

    # Collect all query IDs across all engines
    all_queries = set()
    for eng in engines:
        all_queries |= {p.stem.rsplit("-run", 1)[0] for p in eng["outputs"].glob("*-run*.tsv")}
        all_queries |= set(eng["summary"].keys())
    all_queries = sorted(all_queries)

    # Build result matrix
    rows = []
    mismatches = []
    for qid in all_queries:
        row = {"query_id": qid}
        row_counts = {}
        hashes = {}
        statuses = {}

        for eng in engines:
            name = eng["name"]
            summary_row = eng["summary"].get(qid)
            if summary_row is None:
                row[f"{name}_status"] = "MISSING"
                row[f"{name}_rows"] = ""
                row[f"{name}_ms"] = ""
                statuses[name] = "MISSING"
                continue

            if summary_row["status"] != "200":
                row[f"{name}_status"] = summary_row["status"]
                row[f"{name}_rows"] = ""
                row[f"{name}_ms"] = f"{summary_row['median_ms']:.3f}"
                statuses[name] = "TIMEOUT/ERR"
                continue

            _, median_path = find_median_run(eng["outputs"], qid, summary_row)
            n_rows = count_rows(median_path)
            h = content_hash(median_path)
            row[f"{name}_rows"] = str(n_rows) if n_rows is not None else "?"
            row[f"{name}_ms"] = f"{summary_row['median_ms']:.3f}"
            row[f"{name}_status"] = "OK"
            row_counts[name] = n_rows
            hashes[name] = h
            statuses[name] = "OK"

        # Determine mismatch status
        ok_counts = [v for v in row_counts.values() if v is not None]
        ok_hashes = [v for v in hashes.values() if v is not None]
        if len(set(ok_counts)) > 1:
            row["match"] = "COUNT_MISMATCH"
            mismatches.append(qid)
        elif len(set(ok_hashes)) > 1:
            row["match"] = "CONTENT_MISMATCH"
            mismatches.append(qid)
        elif any(s in ("MISSING", "TIMEOUT/ERR") for s in statuses.values()):
            row["match"] = "PARTIAL"
        else:
            row["match"] = "MATCH"

        rows.append(row)

    # Write output
    eng_names = [e["name"] for e in engines]
    fieldnames = ["query_id", "match"] + [
        f for name in eng_names for f in [f"{name}_rows", f"{name}_ms", f"{name}_status"]
    ]

    out = open(args.out, "w", newline="") if args.out != "-" else sys.stdout
    try:
        writer = csv.DictWriter(out, fieldnames=fieldnames, delimiter="\t",
                                extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    finally:
        if args.out != "-":
            out.close()

    # Summary
    n_match = sum(1 for r in rows if r["match"] == "MATCH")
    n_mismatch = len(mismatches)
    print(f"\n--- Summary ---", file=sys.stderr)
    print(f"  Total queries:     {len(rows)}", file=sys.stderr)
    print(f"  All engines agree: {n_match}", file=sys.stderr)
    print(f"  Count mismatches:  {n_mismatch}", file=sys.stderr)
    if mismatches:
        print(f"  Mismatched queries: {', '.join(mismatches[:20])}", file=sys.stderr)
        if len(mismatches) > 20:
            print(f"    ... and {len(mismatches)-20} more", file=sys.stderr)


if __name__ == "__main__":
    main()
