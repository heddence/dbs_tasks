from fastapi import APIRouter

import psycopg2

from dbs_assignment.config import settings

router = APIRouter()

conn = psycopg2.connect(
    dbname=settings.DATABASE_NAME,
    user=settings.DATABASE_USER,
    password=settings.DATABASE_PASSWORD,
    host=settings.DATABASE_HOST,
    port=settings.DATABASE_PORT
)

cursor = conn.cursor()


@router.get('/v2/posts/{post_id}/users')
async def task1(post_id):
    cursor.execute(
        f"SELECT DISTINCT \
            u.id, u.reputation, c.creationdate, u.displayname, \
            u.lastaccessdate, u.websiteurl, u.location, \
            u.aboutme,  u.views, u.upvotes, u.downvotes, \
            u.profileimageurl, u.age, u.accountid \
          FROM users AS u \
          JOIN comments AS c ON c.userid = u.id \
          JOIN posts AS p ON p.id = c.postid \
          WHERE p.id = {post_id} \
          ORDER BY c.creationdate DESC;"
    )

    rows = cursor.fetchall()

    list_dicts = []
    for row in rows:
        row_dict = {
            "id": row[0],
            "reputation": row[1],
            "creationdate": row[2],
            "displayname": row[3],
            "lastaccessdate": row[4],
            "websiteurl": row[5],
            "location": row[6],
            "aboutme": row[7],
            "views": row[8],
            "upvotes": row[9],
            "downvotes": row[10],
            "profileimageurl": row[11],
            "age": row[12],
            "accountid": row[13]
        }
        list_dicts.append(row_dict)

    return {
        "items": list_dicts
    }


@router.get('/v2/users/{user_id}/friends')
async def task2(user_id):
    cursor.execute(
        f"SELECT DISTINCT \
            u.id, u.reputation, u.creationdate, u.displayname, \
            u.lastaccessdate, u.websiteurl, u.location, \
            u.aboutme,  u.views, u.upvotes, u.downvotes, \
            u.profileimageurl, u.age, u.accountid \
          FROM users AS u \
          JOIN comments AS c ON c.userid = u.id \
          WHERE c.postid IN ( \
            SELECT id FROM posts WHERE owneruserid = {user_id} \
            UNION \
            SELECT postid FROM comments WHERE userid = {user_id}) \
          ORDER BY u.creationdate;"
    )

    rows = cursor.fetchall()

    list_dicts = []
    for row in rows:
        row_dict = {
            "id": row[0],
            "reputation": row[1],
            "creationdate": row[2],
            "displayname": row[3],
            "lastaccessdate": row[4],
            "websiteurl": row[5],
            "location": row[6],
            "aboutme": row[7],
            "views": row[8],
            "upvotes": row[9],
            "downvotes": row[10],
            "profileimageurl": row[11],
            "age": row[12],
            "accountid": row[13]
        }
        list_dicts.append(row_dict)

    return {
        "items": list_dicts
    }


@router.get('/v2/tags/{tagname}/stats')
async def task3(tagname):
    cursor.execute(
        f"WITH total_posts AS ( \
            SELECT \
                extract(ISODOW FROM p.creationdate) AS weekday_all, \
                count(*) AS total_count \
            FROM posts AS p \
            JOIN post_tags AS pt ON p.id = pt.post_id \
            JOIN tags AS t ON pt.tag_id = t.id \
            GROUP BY weekday_all \
            ORDER BY weekday_all \
        ), tag_posts AS ( \
        SELECT \
            extract(ISODOW FROM p.creationdate) AS weekday_tag, \
            count(*) AS tag_count \
        FROM posts AS p \
        JOIN post_tags AS pt ON p.id = pt.post_id \
        JOIN tags AS t ON pt.tag_id = t.id \
        WHERE t.tagname LIKE '%{tagname}%' \
        GROUP BY weekday_tag \
        ORDER BY weekday_tag \
        ) \
        SELECT \
            CASE total_posts.weekday_all \
                WHEN 1 THEN 'Monday' \
                WHEN 2 THEN 'Tuesday' \
                WHEN 3 THEN 'Wednesday' \
                WHEN 4 THEN 'Thursday' \
                WHEN 5 THEN 'Friday' \
                WHEN 6 THEN 'Saturday' \
                WHEN 7 THEN 'Sunday' \
            END, \
            round((tag_posts.tag_count * 100.0 / total_posts.total_count), 2) AS percentage \
        FROM total_posts \
        JOIN tag_posts ON total_posts.weekday_all = tag_posts.weekday_tag;"
    )

    rows = cursor.fetchall()

    return {
        "result": {
            "monday": rows[0][1],
            "tuesday": rows[1][1],
            "wednesday": rows[2][1],
            "thursday": rows[3][1],
            "friday": rows[4][1],
            "saturday": rows[5][1],
            "sunday": rows[6][1]
        }
    }


@router.get('/v2/posts/')
async def task4(duration: int, limit: int):
    cursor.execute(
        f"SELECT p.id, p.creationdate, \
                 p.viewcount, p.lasteditdate, \
                 p.lastactivitydate, \
                 p.title, p.closeddate, \
                 round(extract(EPOCH FROM p.closeddate - p.creationdate) / 60, 2) \
          FROM posts AS p \
          WHERE \
            round(extract(EPOCH FROM p.closeddate - p.creationdate) / 60, 2) <= {duration} AND \
            p.closeddate IS NOT NULL \
          ORDER BY p.closeddate DESC \
          LIMIT {limit};"
    )

    rows = cursor.fetchall()

    list_dicts = []
    for row in rows:
        row_dict = {
            "id": row[0],
            "creationdate": row[1],
            "viewcount": row[2],
            "lasteditdate": row[3],
            "lastactivitydate": row[4],
            "title": row[5],
            "closeddate": row[6],
            "duration": row[7]
        }
        list_dicts.append(row_dict)

    return {
        "items": list_dicts
    }


@router.get('/v2/posts/')
async def task5(limit: int, query: str):
    cursor.execute(
        f"SELECT \
            p.id, p.creationdate, p.viewcount, \
            p.lasteditdate, p.lastactivitydate, \
            p.title, p.body, p.answercount, \
            p.closeddate, t.tagname \
          FROM posts AS p \
          JOIN post_tags AS pt ON p.id = pt.post_id \
          JOIN tags AS t ON pt.tag_id = t.id \
          WHERE p.title LIKE '%{query}%' OR p.body LIKE '%{query}%' \
          ORDER BY p.creationdate DESC \
          LIMIT {limit};"
    )

    rows = cursor.fetchall()

    list_dicts = []
    for row in rows:
        row_dict = {
            "id": row[0],
            "creationdate": row[1],
            "viewcount": row[2],
            "lasteditdate": row[3],
            "lastactivitydate": row[4],
            "title": row[5],
            "body": row[6],
            "answercount": row[7],
            "closeddate": row[8],
            "tags": [row[9]]
        }
        list_dicts.append(row_dict)

    return {
        "items": list_dicts
    }