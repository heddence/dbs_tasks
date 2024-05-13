SELECT DISTINCT
    positions.post_id,
    positions.comment_id,
    positions.display_name,
    positions.post_body,
    positions.comment_text,
    positions.comment_score,
    positions.post_date
FROM (
    SELECT DISTINCT
        p.id AS post_id,
        c.id AS comment_id,
        u.displayname AS display_name,
        p.body AS post_body,
        c.text AS comment_text,
        c.score AS comment_score,
        c.creationdate AS comment_date,
        p.creationdate AS post_date,
        dense_rank() OVER (PARTITION BY p.id ORDER BY c.creationdate) AS rn
    FROM comments c
    JOIN users u ON u.id = c.userid
    JOIN posts p ON p.id = c.postid
    JOIN post_tags pt ON pt.post_id = p.id
    JOIN tags t ON t.id = pt.tag_id
    WHERE t.tagname ILIKE '%linux%'
) AS positions
WHERE positions.rn = 2
ORDER BY positions.post_date
LIMIT 1;
