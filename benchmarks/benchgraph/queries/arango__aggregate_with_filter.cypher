MATCH (n:User) WHERE n.age >= 18 RETURN n.age, COUNT(*)
