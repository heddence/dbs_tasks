from fastapi import APIRouter

from dbs_assignment.endpoints import hello
from dbs_assignment.endpoints import sql_queries1
from dbs_assignment.endpoints import sql_queries2

router = APIRouter()
router.include_router(hello.router, tags=["hello"])
router.include_router(sql_queries1.router, tags=["sql_queries1"])
router.include_router(sql_queries2.router, tags=["sql_queries2"])
