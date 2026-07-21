MATCH (n:User {id: $from}), (m:User {id: $to}) WITH n, m
MATCH p=shortestPath((n)-[*..15]->(m))
WHERE all(node in nodes(p) WHERE node.age >= 18)
RETURN [n in nodes(p) | n.id] AS path
