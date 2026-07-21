MATCH (n:User {id: $id})-[e1]->(m)-[e2]->(n) RETURN e1, m, e2
