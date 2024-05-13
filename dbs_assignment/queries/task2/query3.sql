WITH total_posts AS (
    SELECT
        extract(ISODOW FROM p.creationdate) AS weekday_all,
        count(*) AS total_count
    FROM posts AS p
    JOIN post_tags AS pt ON p.id = pt.post_id
    JOIN tags AS t ON pt.tag_id = t.id
    GROUP BY weekday_all
    ORDER BY weekday_all
), tag_posts AS (
    SELECT
        extract(ISODOW FROM p.creationdate) AS weekday_tag,
        count(*) AS tag_count
    FROM posts AS p
    JOIN post_tags AS pt ON p.id = pt.post_id
    JOIN tags AS t ON pt.tag_id = t.id
    WHERE t.tagname LIKE '%linux%'
    GROUP BY weekday_tag
    ORDER BY weekday_tag
)
SELECT
    CASE total_posts.weekday_all
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END,
    round((tag_posts.tag_count * 100.0 / total_posts.total_count), 2) AS percentage
FROM total_posts
JOIN tag_posts ON total_posts.weekday_all = tag_posts.weekday_tag;