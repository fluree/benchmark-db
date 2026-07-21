MATCH (n:User {id: $from}), (m:User {id: $to})
WITH shortestPath((n)-[*..15]->(m)) AS p
RETURN [x IN nodes(p) | x.id] AS path
