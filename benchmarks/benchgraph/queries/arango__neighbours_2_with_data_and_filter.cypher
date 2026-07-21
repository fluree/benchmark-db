MATCH (s:User {id: $id})-[*1..2]->(n:User)
WHERE n.age >= 18
RETURN DISTINCT n.id, n
