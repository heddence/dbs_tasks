SELECT
    helper.post_id,
    helper.post_title,
    helper.post_date,
    helper.badge_id,
    helper.badge_name,
    helper.badge_date
FROM
(
SELECT
    b.id AS badge_id,
    b.date AS badge_date,
    b.name AS badge_name,

    p.id AS post_id,
    p.creationdate AS post_date,
    p.title AS post_title,

    row_number() OVER (PARTITION BY b.id ORDER BY p.creationdate DESC) AS rn_bp,
    row_number() OVER (PARTITION BY p.id ORDER BY p.id DESC) AS rn_p
FROM badges b
JOIN posts p ON p.owneruserid = b.userid
WHERE p.owneruserid = 120 AND
      p.creationdate < b.date
ORDER BY b.date
) AS helper
WHERE helper.rn_bp = 1 AND
      helper.rn_p = 1;
