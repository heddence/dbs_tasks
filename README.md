# dbs_tasks
SQL tasks in the database course

The task was aimed at creating SQL queries over the PostgreSQL database, which was created from the [Stack Exchange Data Dump Superuser dataset](https://archive.org/details/stackexchange). The goal was to implement the below tasks as RESTful endpoints, which are implemented as SQL queries, transformed into JSON output.

Task 2:
1. GET /v2/posts/:post_id/users
Return a list of all discussants (users) of the post (posts) with the ID :post_id, sorting them according to when their comment was made, starting with the newest and ending with the oldest.
2. GET /v2/users/:user_id/friends
Produce a discussion list for the user user id, containing users who have commented on posts that the user has created or commented on.
3. GET /v2/tags/:tagname/stats
Determine the percentage of posts with a particular tag within the total number of posts published on each day of the week (e.g. Monday, Tuesday), for each day of the week separately. Show the results on a scale of 0 - 100 and round to two decimal places.
4. GET /v2/posts/?duration=:duration_in_minutes&limit=:limit
The output is a list of the :limit of the most recently resolved posts that have been opened for a maximum of :duration_in_minutes minutes (the number of minutes between creationdate and closeddate). Round the opening duration (duration) to two decimal places.
5. GET /v2/posts?limit=:limit&query=:query
Suggest an endpoint that provides a list of posts ordered from newest to oldest. Include a complete list of associated tags as part of the response.

Task 3:
1. GET /v3/users/:user_id/badge_history
For the selected user, analyze the badges he/she has earned by outputting all the badges he/she has earned, along with the previous report the author wrote before earning the badge. If he has earned a badge and no message has been sent before the badge, the badge will not be displayed in the output. For example, if he has earned 2 badges and several messages have been sent before, then only the first badge is displayed in the output, with the last message preceding it being shown.
2. GET /v3/tags/:tag/comments?count=:count
For a given tag, calculate the average response time between comments for individual posts that have more than the specified number of comments within that post. In the output, indicate how the individual average response time changed as more comments were added
3. GET /v3/tags/:tagname/comments/:position?limit=:limit
Return comments for posts with the :tagname tag that were created as k's in order (:position) sorted by creation date procedure with :limit.
4. GET /v3/posts/:postid?limit=:limit
The output is a list of :thread limit size for the post with postid ID. The thread starts with postid and continues with posts, where postid is a parentid sorted by creation date starting from the oldest.

Task 4:
The main objective is to design the database by creating a relational data model (physical model) in the form of a relational diagram for the museum database.
