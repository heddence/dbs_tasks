SELECT DISTINCT
    u.id, u.reputation, u.creationdate, u.displayname,
    u.lastaccessdate, u.websiteurl, u.location,
    u.aboutme,  u.views, u.upvotes, u.downvotes,
    u.profileimageurl, u.age, u.accountid
FROM users AS u
JOIN comments AS c ON c.userid = u.id
WHERE c.postid IN (
SELECT id FROM posts WHERE owneruserid = 1
UNION
SELECT postid FROM comments WHERE userid = 1)
ORDER BY u.creationdate;