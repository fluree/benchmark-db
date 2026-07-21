#!/usr/bin/env python3
"""Convert a benchgraph Pokec Cypher import file to Turtle for Fluree bulk import.

The upstream files (deps.memgraph.io/dataset/pokec/benchmark/) contain exactly
two statement shapes:

  CREATE (:User {id: N, completion_percentage: N, gender: "man", age: N});
  MATCH (n:User {id: A}), (m:User {id: B}) CREATE (n)-[e: Friend]->(m);

Fluree's Cypher surface resolves bare names against the ledger @context,
falling back to http://example.org/ when none is configured. We emit that
vocab so the benchmark queries (`MATCH (n:User {id: $id})`, untyped `-->`
traversal over the Friend edges) match the imported data with a zero-config
ledger.

Edges are emitted as plain triples (no reifier bundles) — the property-graph
equivalent of PROPERTIES_ON_EDGES = False, and what Cypher's un-bound
`(a)-[:T]->(b)` / `-->` patterns match.

Usage: pokec_to_ttl.py <input.cypher> <output.ttl>
"""
import re
import sys

# Node properties vary: pokec_large has users with only {id,
# completion_percentage} (no gender/age), so parse the property blob
# generically instead of assuming the full four-key shape.
NODE_RE = re.compile(r"CREATE \(:User \{(.+)\}\);")
PROP_RE = re.compile(r'(\w+): (?:"([^"]*)"|(\d+))')
EDGE_RE = re.compile(
    r'MATCH \(n:User \{id: (\d+)\}\), \(m:User \{id: (\d+)\}\) '
    r'CREATE \(n\)-\[e: ?Friend\]->\(m\);'
)


def main(src: str, dst: str) -> None:
    nodes = edges = skipped = 0
    with open(src) as f, open(dst, "w") as out:
        out.write("@prefix : <http://example.org/> .\n")
        out.write("@prefix u: <http://example.org/user/> .\n\n")
        for line in f:
            line = line.strip()
            if not line or line == ";":
                continue
            m = NODE_RE.match(line)
            if m:
                props = {}
                quoted = set()
                for pm in PROP_RE.finditer(m.group(1)):
                    if pm.group(2) is not None:
                        props[pm.group(1)] = pm.group(2)
                        quoted.add(pm.group(1))
                    else:
                        props[pm.group(1)] = pm.group(3)
                uid = props.pop("id")
                parts = [f"u:{uid} a :User ; :id {uid}"]
                for k, v in props.items():
                    parts.append(f':{k} "{v}"' if k in quoted else f":{k} {v}")
                out.write(" ; ".join(parts) + " .\n")
                nodes += 1
                continue
            m = EDGE_RE.match(line)
            if m:
                out.write(f"u:{m.group(1)} :Friend u:{m.group(2)} .\n")
                edges += 1
                continue
            skipped += 1
            print(f"WARN unparsed line: {line[:100]}", file=sys.stderr)
    print(f"nodes={nodes} edges={edges} skipped={skipped}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
