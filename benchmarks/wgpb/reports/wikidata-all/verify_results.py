#!/usr/bin/env python3
"""Verify the published WGPB samples and archived evidence, without a server."""

import csv
import hashlib
import json
import math
import statistics
import tarfile
from collections import defaultdict
from pathlib import Path


def check(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    report = Path(__file__).resolve().parent
    evidence = report / "evidence"
    meta = json.loads((report / "meta.json").read_text())
    manifest = json.loads((evidence / "archive-manifest.json").read_text())
    archive = evidence / manifest["file"]
    check(archive.stat().st_size == manifest["bytes"], "Archive size mismatch")
    check(hashlib.sha256(archive.read_bytes()).hexdigest() == manifest["sha256"],
          "Archive checksum mismatch")
    with (report / "engines/fluree.tsv").open() as source:
        samples = list(csv.DictReader(source, delimiter="\t"))
    with (report / "engines/fluree_summary.tsv").open() as source:
        summary = list(csv.DictReader(source, delimiter="\t"))
    check(len(samples) == 2550 and len(summary) == 850, "Wrong sample count")
    grouped = defaultdict(list)
    for row in samples:
        check(row["status"] == "200" and not row["error"], "Failed request")
        check(math.isfinite(float(row["time_ms"])) and float(row["time_ms"]) > 0,
              "Invalid latency")
        grouped[row["query_id"]].append(row)
    check(len(grouped) == 850, "Wrong query count")
    for row in summary:
        runs = grouped[row["query_id"]]
        check(len(runs) == 3 and {r["run"] for r in runs} == {"1", "2", "3"},
              "Missing or duplicate repetition")
        times = [float(r["time_ms"]) for r in runs]
        for key, value in [("median_ms", statistics.median(times)),
                           ("min_ms", min(times)), ("max_ms", max(times))]:
            check(float(row[key]) == value, f"Summary mismatch: {row['query_id']} {key}")
        check(row["status"] == "200" and not row["error"], "Failed summary")
        check(row["result_size"] == runs[-1]["result_size"], "Summary byte mismatch")
    values = [float(row["median_ms"]) for row in summary]
    aggregates = {
        "geo_mean_ms": statistics.geometric_mean(values),
        "median_ms": statistics.median(values),
        "arith_mean_ms": statistics.mean(values),
        "max_ms": max(values),
        **{f"under_{n}ms": sum(t < n for t in values) for n in (100, 500, 1000)},
    }
    for key, value in aggregates.items():
        check(math.isclose(meta["results"][key], value, rel_tol=1e-12),
              f"Metadata mismatch: {key}")

    with tarfile.open(archive) as bundle:
        def read(name):
            return bundle.extractfile(name).read()

        for published, archived in [("engines/fluree.tsv", "results/full.tsv"),
                                     ("engines/fluree_summary.tsv", "results/full_summary.tsv"),
                                     ("evidence/build.json", "candidate-build.json"),
                                     ("evidence/ti3-validation.json", "results/ti3-validation/summary.json")]:
            check((report / published).read_bytes() == read(archived),
                  f"Published copy differs from archive: {published}")
        query_hashes = read("results/query-hashes.sha256").decode().splitlines()
        check(len(query_hashes) == 850, "Wrong query hash count")
        query_ids = set()
        for line in query_hashes:
            digest, name = line.split()
            query_ids.add(Path(name).stem)
            check(hashlib.sha256(read(name)).hexdigest() == digest, f"Archived query: {name}")
            check(hashlib.sha256((report.parents[1] / name).read_bytes()).hexdigest() == digest,
                  f"Published query differs: {name}")
        check(query_ids == set(grouped) == {r["query_id"] for r in summary}, "Query IDs differ")
        for row in samples:
            body = read(f"results/full-outputs/{row['query_id']}-run{row['run']}.tsv")
            check(len(body) == int(row["result_size"]), "Response byte count mismatch")

        # Recompute the triple checks from the saved JSON, independently of its verdict.
        response = read("results/target-json/TI3-40-run0.json")
        validation = json.loads((evidence / "ti3-validation.json").read_text())
        check(hashlib.sha256(response).hexdigest() == validation["source_response_sha256"],
              "TI3-40 response checksum mismatch")
        rows = json.loads(response)["results"]["bindings"]
        def term(binding):
            return json.dumps(binding, sort_keys=True, separators=(",", ":"))
        check(len(rows) == len({term(r) for r in rows}) == 1000, "TI3-40 solution count")
        for variable, predicate in [("y", "P2884"), ("z", "P2547"), ("u", "P1082")]:
            bindings = json.loads(read(f"results/ti3-validation/{predicate}.json"))["results"]["bindings"]
            pairs = {(r["s"]["value"], term(r["value"])) for r in bindings}
            check(all((r[variable]["value"], term(r["x"])) in pairs for r in rows),
                  f"Missing source triple: {predicate}")

    counts = json.loads((evidence / "import-reconciliation.json").read_text())
    check(counts["count"] == counts["indexed"] == meta["dataset"]["triples"], "Triple count mismatch")
    check(counts["count"] + counts["duplicates"] == counts["input_records"]
          == meta["dataset"]["input_records"], "Input reconciliation mismatch")
    build = json.loads((evidence / "build.json").read_text())
    for key in ("commit", "binary_sha256"):
        check(build[key] == meta["engine"][key], f"Build identity mismatch: {key}")
    print("Verified 850 queries, 2,550 samples and response sizes, summaries, query hashes,")
    print("archive checksum, build identity, import reconciliation and all 3,000 TI3-40 source triples.")
    print(json.dumps(aggregates, indent=2))


if __name__ == "__main__":
    main()
