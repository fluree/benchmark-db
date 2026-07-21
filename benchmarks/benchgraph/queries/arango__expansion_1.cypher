MATCH (s:User {id: $id})-->(n:User) RETURN n.id
