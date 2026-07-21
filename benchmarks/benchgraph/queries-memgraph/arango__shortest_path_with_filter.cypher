MATCH (n:User {id: $from}), (m:User {id: $to}) WITH n, m
MATCH p=(n)-[*bfs..15 (e, n | n.age >= 18)]->(m)
RETURN extract(n in nodes(p) | n.id) AS path
