from fastapi import APIRouter

import psycopg2

from dbs_assignment.config import settings

router = APIRouter()


@router.get('/v3/users/{user_id}/badge_history')
async def get_badge_history(user_id):
    conn = psycopg2.connect(
        dbname=settings.DATABASE_NAME,
        user=settings.DATABASE_USER,
        password=settings.DATABASE_PASSWORD,
        host=settings.DATABASE_HOST,
        port=settings.DATABASE_PORT
    )

    try:
        with conn.cursor() as cur:
            cur.execute(f" \
                SELECT \
                    helper.post_id, \
                    helper.post_title, \
                    helper.post_date, \
                    helper.badge_id, \
                    helper.badge_name, \
                    helper.badge_date \
                FROM \
                ( \
                SELECT \
                    b.id AS badge_id, \
                    b.date AS badge_date, \
                    b.name AS badge_name, \
                    p.id AS post_id, \
                    p.creationdate AS post_date, \
                    p.title AS post_title, \
                    row_number() OVER (PARTITION BY b.id ORDER BY p.creationdate DESC) AS rn_bp, \
                    row_number() OVER (PARTITION BY p.id ORDER BY p.id DESC) AS rn_p \
                FROM badges b \
                JOIN posts p ON p.owneruserid = b.userid \
                WHERE p.owneruserid = {user_id} AND \
                      p.creationdate < b.date \
                ORDER BY b.date \
                ) AS helper \
                WHERE helper.rn_bp = 1 AND \
                      helper.rn_p = 1; \
            ")

            rows = cur.fetchall()
    finally:
        conn.close()

    result_list = []
    position = 1
    for row in rows:
        result_dict = {
            "id": row[0],
            "title": row[1],
            "type": "post",
            "created_at": row[2],
            "position": position
        }
        result_list.append(result_dict)

        result_dict = {
            "id": row[3],
            "title": row[4],
            "type": "badge",
            "created_at": row[5],
            "position": position
        }
        result_list.append(result_dict)
        position += 1

    return {"items": result_list}


@router.get('/v3/tags/{tag}/comments')
async def get_comments(tag, count):
    conn = psycopg2.connect(
        dbname=settings.DATABASE_NAME,
        user=settings.DATABASE_USER,
        password=settings.DATABASE_PASSWORD,
        host=settings.DATABASE_HOST,
        port=settings.DATABASE_PORT
    )

    try:
        with conn.cursor() as cur:
            cur.execute(f" \
                SELECT \
                    helper.post_id, \
                    helper.post_title, \
                    helper.display_name, \
                    helper.comment_text, \
                    helper.post_date, \
                    helper.comment_date, \
                    to_char(helper.diff, 'HH24:MI:SS.MS'), \
                    to_char(avg(helper.diff) OVER ( \
                        PARTITION BY helper.post_id \
                        ORDER BY helper.comment_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW \
                    ), 'HH24:MI:SS.MS') AS avg \
                FROM \
                ( \
                SELECT \
                    p.id AS post_id, \
                    p.title AS post_title, \
                    u.displayname AS display_name, \
                    c.text AS comment_text, \
                    p.creationdate AS post_date, \
                    c.creationdate AS comment_date, \
                    c.creationdate - lag(c.creationdate, 1, p.creationdate) OVER ( \
                        PARTITION BY p.id \
                        ORDER BY c.creationdate \
                    ) AS diff \
                FROM posts p \
                JOIN post_tags pt ON pt.post_id = p.id \
                JOIN tags t ON t.id = pt.tag_id \
                JOIN comments c ON c.postid = p.id \
                JOIN users u ON u.id = c.userid \
                WHERE p.commentcount > {count} AND \
                      t.tagname ILIKE '%{tag}%' \
                ORDER BY c.creationdate \
                ) AS helper; \
            ")

            results = cur.fetchall()
    finally:
        conn.close()

    result_list = []
    for result in results:
        result_dict = {
            "post_id": result[0],
            "title": result[1],
            "displayname": result[2],
            "text": result[3],
            "post_created_at": result[4],
            "created_at": result[5],
            "diff": result[6],
            "avg": result[7]
        }
        result_list.append(result_dict)

    return {"items": result_list}


@router.get('/v3/tags/{tagname}/comments/{position}')
async def get_comments_position(tagname, position, limit):
    conn = psycopg2.connect(
        dbname=settings.DATABASE_NAME,
        user=settings.DATABASE_USER,
        password=settings.DATABASE_PASSWORD,
        host=settings.DATABASE_HOST,
        port=settings.DATABASE_PORT
    )

    try:
        with conn.cursor() as cur:
            cur.execute(f" \
                SELECT DISTINCT \
                    positions.post_id, \
                    positions.comment_id, \
                    positions.display_name, \
                    positions.post_body, \
                    positions.comment_text, \
                    positions.comment_score, \
                    positions.post_date \
                FROM ( \
                    SELECT DISTINCT \
                        p.id AS post_id, \
                        c.id AS comment_id, \
                        u.displayname AS display_name, \
                        p.body AS post_body, \
                        c.text AS comment_text, \
                        c.score AS comment_score, \
                        c.creationdate AS comment_date, \
                        p.creationdate AS post_date, \
                        dense_rank() OVER (PARTITION BY p.id ORDER BY c.creationdate) AS rn \
                    FROM comments c \
                    JOIN users u ON u.id = c.userid \
                    JOIN posts p ON p.id = c.postid \
                    JOIN post_tags pt ON pt.post_id = p.id \
                    JOIN tags t ON t.id = pt.tag_id \
                    WHERE t.tagname ILIKE '%{tagname}%' \
                ) AS positions \
                WHERE positions.rn = {position} \
                ORDER BY positions.post_date \
                LIMIT {limit}; \
            ")

            results = cur.fetchall()
    finally:
        conn.close()

    result_list = []
    for result in results:
        result_dict = {
            "id": result[1],
            "displayname": result[2],
            "body": result[3],
            "text": result[4],
            "score": result[5],
            "position": int(position)
        }
        result_list.append(result_dict)

    return {"items": result_list}


@router.get('/v3/posts/{post_id}')
async def get_post_by_id(post_id, limit):
    conn = psycopg2.connect(
        dbname=settings.DATABASE_NAME,
        user=settings.DATABASE_USER,
        password=settings.DATABASE_PASSWORD,
        host=settings.DATABASE_HOST,
        port=settings.DATABASE_PORT
    )

    try:
        with conn.cursor() as cur:
            cur.execute(f" \
                SELECT \
                    posts.id, \
                    posts.parentid, \
                    users.displayname, \
                    posts.body, \
                    posts.creationdate \
                FROM posts \
                JOIN users ON users.id = posts.owneruserid \
                WHERE posts.id = {post_id} \
                UNION ALL \
                SELECT \
                    child.id, \
                    child.parentid, \
                    users.displayname, \
                    child.body, \
                    child.creationdate \
                FROM posts child \
                JOIN posts parent ON child.parentid = parent.id \
                JOIN users ON users.id = child.owneruserid \
                WHERE parent.id = {post_id} \
                ORDER BY creationdate \
                LIMIT {limit}; \
            ")

            results = cur.fetchall()
    finally:
        conn.close()

    result_list = []
    for result in results:
        result_dict = {
            "displayname": result[2],
            "body": result[3],
            "created_at": result[4]
        }
        result_list.append(result_dict)

    return {"items": result_list}
