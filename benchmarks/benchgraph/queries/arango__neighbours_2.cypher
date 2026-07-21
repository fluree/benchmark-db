MATCH (s:User {id: $id})-[*1..2]->(n:User) RETURN DISTINCT n.id
