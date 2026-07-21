MATCH (s:User {id: $id})-->()-->()-->(n:User)
WHERE n.age >= 18
RETURN DISTINCT n.id
