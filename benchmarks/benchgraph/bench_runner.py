#!/usr/bin/env python3
"""Unified benchgraph Pokec runner for Fluree, Neo4j, and Memgraph.

One runner so every engine sees IDENTICAL parameter values per query — the
param sequence is generated once (seeded), cached to a JSON file, and
replayed for each engine. This matters: expansion_4 from a hub seed vs a
leaf seed differs by orders of magnitude, so cross-engine numbers are only
comparable if the seed vertices match.

Transports:
  - fluree : HTTP  POST {"cypher","params"} to /v1/fluree/query|update/<ledger>
  - neo4j  : Bolt (default) via the neo4j Python driver, or --http
  - memgraph: Bolt via the neo4j Python driver

Query texts are the verbatim Neo4j-portable branch in queries/. For Memgraph,
the 3 path queries use native syntax from queries-memgraph/ if present.

Output: TSV identical to run_benchmark.sh
  query_id, description, run, status, time_ms, result_size, error
"""
import argparse
import csv
import json
import random
import statistics
import sys
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent


def gen_params(spec, rng, nv):
    if spec == "none":
        return {}
    if spec == "id":
        return {"id": rng.randint(1, nv)}
    if spec == "id10x":
        return {"id": rng.randint(1, nv * 10)}
    if spec == "from_to":
        a = rng.randint(1, nv)
        b = a
        while b == a:
            b = rng.randint(1, nv)
        return {"from": a, "to": b}
    raise ValueError(f"unknown param spec: {spec}")


def load_queryset(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f, delimiter="\t"):
            rows.append(r)
    return rows


def build_params(queryset, seed, nv, n, cache_file):
    """Deterministic param sequence per query, cached so all engines match."""
    if cache_file and Path(cache_file).exists():
        return json.loads(Path(cache_file).read_text())
    rng = random.Random(seed)
    out = {}
    for r in sorted(queryset, key=lambda x: x["query_id"]):
        out[r["query_id"]] = [gen_params(r["params"], rng, nv) for _ in range(n)]
    if cache_file:
        Path(cache_file).write_text(json.dumps(out, indent=0))
    return out


# --- transports -------------------------------------------------------------

def http_call(url, cypher, params, timeout, is_write):
    body = json.dumps({"cypher": cypher, "params": params}).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/cypher"}
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
        dt = (time.perf_counter() - t0) * 1000
        if "results" in data:
            size = len(data["results"][0]["data"])
        elif data.get("tx-id"):
            size = 1
        else:
            size = 0
        return dt, size, None
    except urllib.error.HTTPError as e:
        dt = (time.perf_counter() - t0) * 1000
        return dt, None, e.read()[:200].decode("utf-8", "replace")
    except Exception as e:
        dt = (time.perf_counter() - t0) * 1000
        return dt, None, str(e)[:200]


def neo4j_http_call(url, auth_header, cypher, params, timeout):
    """Neo4j transactional HTTP endpoint: POST /db/neo4j/tx/commit."""
    body = json.dumps(
        {"statements": [{"statement": cypher, "parameters": params}]}
    ).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": auth_header,
        },
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
        dt = (time.perf_counter() - t0) * 1000
        errs = data.get("errors") or []
        if errs:
            return dt, None, str(errs[0])[:200]
        size = len(data["results"][0]["data"]) if data.get("results") else 0
        return dt, size, None
    except urllib.error.HTTPError as e:
        return (time.perf_counter() - t0) * 1000, None, e.read()[:200].decode("utf-8", "replace")
    except Exception as e:
        return (time.perf_counter() - t0) * 1000, None, str(e)[:200]


def bolt_call(driver, cypher, params, timeout):
    t0 = time.perf_counter()
    try:
        with driver.session() as s:
            res = s.run(cypher, parameters=params)
            rows = list(res)  # materialize result stream
        dt = (time.perf_counter() - t0) * 1000
        return dt, len(rows), None
    except Exception as e:
        dt = (time.perf_counter() - t0) * 1000
        return dt, None, str(e)[:200]


def falkordb_call(graph, cypher, params, timeout):
    t0 = time.perf_counter()
    try:
        res = graph.query(cypher, params=params)
        rows = res.result_set
        dt = (time.perf_counter() - t0) * 1000
        return dt, len(rows), None
    except Exception as e:
        dt = (time.perf_counter() - t0) * 1000
        return dt, None, str(e)[:200]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", required=True, choices=["fluree", "fluree_bolt", "neo4j", "neo4j_http", "memgraph", "falkordb"])
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--bolt-port", type=int, default=7687)
    ap.add_argument("--http-port", type=int, default=8090)
    ap.add_argument("--ledger", default="pokec")  # fluree only
    ap.add_argument("--queries-dir", default=str(HERE / "queries"))
    ap.add_argument("--queryset", default=str(HERE / "query-set.tsv"))
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--warmup", type=int, default=2)
    ap.add_argument("--num-vertices", type=int, default=10000)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--params-file", default=str(HERE / "params_small.json"))
    ap.add_argument("--output", required=True)
    ap.add_argument("--skip-writes", action="store_true")
    ap.add_argument("--redis-port", type=int, default=6379)  # falkordb
    ap.add_argument("--graph", default="pokec")  # falkordb graph name
    args = ap.parse_args()

    qs = load_queryset(args.queryset)
    total = args.warmup + args.runs
    params = build_params(qs, args.seed, args.num_vertices, total, args.params_file)

    driver = None
    if args.engine in ("neo4j", "memgraph", "fluree_bolt"):
        from neo4j import GraphDatabase

        uri = f"bolt://{args.host}:{args.bolt_port}"
        # Fluree Bolt v1 runs open (no auth); Memgraph unauthenticated too.
        auth = ("neo4j", "benchpass") if args.engine == "neo4j" else None
        driver = GraphDatabase.driver(uri, auth=auth)

    fdb_graph = None
    if args.engine == "falkordb":
        from falkordb import FalkorDB
        fdb = FalkorDB(host=args.host, port=args.redis_port)
        fdb_graph = fdb.select_graph(args.graph)

    fluree_q = f"http://{args.host}:{args.http_port}/v1/fluree/query/{args.ledger}:main"
    fluree_u = f"http://{args.host}:{args.http_port}/v1/fluree/update/{args.ledger}:main"
    n4http_url = f"http://{args.host}:{args.http_port}/db/neo4j/tx/commit"
    import base64 as _b64
    n4http_auth = "Basic " + _b64.b64encode(b"neo4j:benchpass").decode()

    mg_over = HERE / "queries-memgraph"
    fdb_over = HERE / "queries-falkordb"

    out = open(args.output, "w")
    out.write("query_id\tdescription\trun\tstatus\ttime_ms\tresult_size\terror\n")
    npass = nfail = nskip = 0

    for r in qs:
        qid, kind, desc = r["query_id"], r["kind"], r["description"]
        if args.skip_writes and kind == "write":
            nskip += 1
            continue
        qfile = Path(args.queries_dir) / f"{qid}.cypher"
        if args.engine == "memgraph" and (mg_over / f"{qid}.cypher").exists():
            qfile = mg_over / f"{qid}.cypher"
        elif args.engine == "falkordb" and (fdb_over / f"{qid}.cypher").exists():
            qfile = fdb_over / f"{qid}.cypher"
        cypher = qfile.read_text().strip()

        failed = False
        last_dt = last_size = last_err = None
        for i in range(total):
            p = params[qid][i]
            if args.engine == "fluree":
                url = fluree_u if kind == "write" else fluree_q
                dt, size, err = http_call(url, cypher, p, args.timeout, kind == "write")
            elif args.engine == "neo4j_http":
                dt, size, err = neo4j_http_call(n4http_url, n4http_auth, cypher, p, args.timeout)
            elif args.engine == "falkordb":
                dt, size, err = falkordb_call(fdb_graph, cypher, p, args.timeout)
            else:
                dt, size, err = bolt_call(driver, cypher, p, args.timeout)
            status = 200 if err is None else 400
            last_dt, last_size, last_err = dt, size, err
            if err is not None:
                failed = True
            if i >= args.warmup:
                label = f"run{i - args.warmup + 1}"
                out.write(
                    f"{qid}\t{desc}\t{label}\t{status}\t{dt:.3f}\t"
                    f"{size if size is not None else ''}\t{err or ''}\n"
                )
        if failed:
            nfail += 1
            print(f"FAIL  {qid} — {last_err}")
        else:
            npass += 1
            print(f"OK    {qid}  ({last_dt:.2f}ms, rows={last_size})")

    out.close()
    if driver:
        driver.close()
    print(f"\n=== {args.engine}: {npass} ok, {nfail} failed, {nskip} skipped -> {args.output} ===")


if __name__ == "__main__":
    main()
