SELECT
    helper.post_id,
    helper.post_title,
    helper.display_name,
    helper.comment_text,
    helper.post_date,
    helper.comment_date,
    to_char(helper.diff, 'HH24:MI:SS.MS'),
    to_char(avg(helper.diff) OVER (
        PARTITION BY helper.post_id
        ORDER BY helper.comment_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 'HH24:MI:SS.MS') AS avg
FROM
(
SELECT
    p.id AS post_id,
    p.title AS post_title,
    u.displayname AS display_name,
    c.text AS comment_text,
    p.creationdate AS post_date,
    c.creationdate AS comment_date,
    c.creationdate - lag(c.creationdate, 1, p.creationdate) OVER (
        PARTITION BY p.id
        ORDER BY c.creationdate
    ) AS diff
FROM posts p
JOIN post_tags pt ON pt.post_id = p.id
JOIN tags t ON t.id = pt.tag_id
JOIN comments c ON c.postid = p.id
JOIN users u ON u.id = c.userid
WHERE p.commentcount > 40 AND
      t.tagname ILIKE '%networking%'
ORDER BY c.creationdate
) AS helper;
