SELECT
    p.id, p.creationdate, p.viewcount,
    p.lasteditdate, p.lastactivitydate,
    p.title, p.body, p.answercount,
    p.closeddate, t.tagname
FROM posts AS p
JOIN post_tags AS pt ON p.id = pt.post_id
JOIN tags AS t ON pt.tag_id = t.id
WHERE p.title LIKE '%linux%' OR p.body LIKE '%linux%'
ORDER BY p.creationdate DESC
LIMIT 1;