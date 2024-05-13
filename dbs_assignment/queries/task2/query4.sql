SELECT
    p.id, p.creationdate,
    p.viewcount, p.lasteditdate,
    p.lastactivitydate,
    p.title, p.closeddate,
    round(extract(EPOCH FROM p.closeddate - p.creationdate) / 60, 2)
FROM posts AS p
WHERE
    round(extract(EPOCH FROM p.closeddate - p.creationdate) / 60, 2) <= {duration} AND
    p.closeddate IS NOT NULL
ORDER BY p.closeddate DESC
LIMIT 1;