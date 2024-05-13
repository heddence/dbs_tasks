SELECT DISTINCT
    u.id, u.reputation, c.creationdate, u.displayname,
    u.lastaccessdate, u.websiteurl, u.location,
    u.aboutme,  u.views, u.upvotes, u.downvotes,
    u.profileimageurl, u.age, u.accountid
FROM users AS u
JOIN comments AS c ON c.userid = u.id
JOIN posts AS p ON p.id = c.postid
WHERE p.id = 1
ORDER BY c.creationdate DESC;