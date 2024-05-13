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


@router.get("/v1/status")
async def hello():
    cursor.execute('SELECT VERSION()')
    row = cursor.fetchone()

    return {
        'version': row[0]
    }

# cursor.close()
