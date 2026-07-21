MATCH (n:User {id: $from}), (m:User {id: $to})
WITH shortestPath((n)-[*..15]->(m)) AS p
WHERE all(node IN nodes(p) WHERE node.age >= 18)
RETURN [x IN nodes(p) | x.id] AS path
