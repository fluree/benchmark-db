MATCH (n:User {id: $id})-[e]->(m) RETURN m LIMIT 1
