from fastapi import APIRouter, Query
from database import get_connection

router = APIRouter()

@router.get("/current")
def current_inventory(warehouse_id: int | None = Query(None)):
    sql = "SELECT * FROM mv_inventory_snapshot"
    params = []
    if warehouse_id is not None:
        sql += " WHERE warehouse_id = %s"
        params.append(warehouse_id)
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()

@router.get("/below-reorder")
def below_reorder():
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute("SELECT * FROM mv_inventory_snapshot WHERE needs_reorder = true;")
        return cur.fetchall()
        