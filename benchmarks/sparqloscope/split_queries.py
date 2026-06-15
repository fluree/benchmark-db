#!/usr/bin/env python3
"""Split a SPARQLoscope benchmark TSV into individual .sparql files.

Usage:
    ./split_queries.py                         # DBLP set -> ./queries/  (default)
    ./split_queries.py <benchmark.tsv> <out_dir>

e.g. the Wikidata-Truthy set (co-located under its dataset dir):
    ./split_queries.py datasets/wikidata-truthy/wikidata-truthy.benchmark.tsv \
                       datasets/wikidata-truthy/queries
"""

import os
import sys
import csv

_HERE = os.path.dirname(__file__)
TSV_FILE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(_HERE, "dblp.benchmark.tsv")
QUERIES_DIR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_HERE, "queries")

os.makedirs(QUERIES_DIR, exist_ok=True)

count = 0
with open(TSV_FILE, "r") as f:
    reader = csv.reader(f, delimiter="\t")
    for row in reader:
        if len(row) < 2:
            continue
        query_id_desc = row[0].strip()
        sparql = row[1].strip()

        # Extract query_id (before the bracket) and description (inside brackets)
        if "[" in query_id_desc:
            query_id = query_id_desc.split("[")[0].strip()
            description = query_id_desc.split("[")[1].rstrip("]").strip()
        else:
            query_id = query_id_desc
            description = ""

        filename = os.path.join(QUERIES_DIR, f"{query_id}.sparql")
        with open(filename, "w") as qf:
            if description:
                qf.write(f"# {description}\n")
            qf.write(sparql + "\n")
        count += 1

print(f"Wrote {count} query files to {QUERIES_DIR}")
