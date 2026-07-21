MATCH (s:User {id: $id})-->()-->()-->(n:User) RETURN DISTINCT n.id
