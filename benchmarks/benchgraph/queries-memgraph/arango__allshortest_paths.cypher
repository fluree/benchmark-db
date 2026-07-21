MATCH (n:User {id: $from}), (m:User {id: $to}) WITH n, m
MATCH p=(n)-[*allshortest 2 (r, n | 1) total_weight]->(m)
RETURN extract(n in nodes(p) | n.id) AS path
