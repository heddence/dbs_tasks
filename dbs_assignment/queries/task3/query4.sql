SELECT
    posts.id,
    posts.parentid,
    users.displayname,
    posts.body,
    posts.creationdate
FROM posts
JOIN users ON users.id = posts.owneruserid
WHERE posts.id = 2154
UNION ALL
SELECT
    child.id,
    child.parentid,
    users.displayname,
    child.body,
    child.creationdate
FROM posts child
JOIN posts parent ON child.parentid = parent.id
JOIN users ON users.id = child.owneruserid
WHERE parent.id = 2154
ORDER BY creationdate
LIMIT 2;
