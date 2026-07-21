MATCH (n:User {id: $from}), (m:User {id: $to}) WITH n, m
MATCH p = allShortestPaths((n)-[*..2]->(m))
RETURN [x IN nodes(p) | x.id] AS path
