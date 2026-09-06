from fastapi import APIRouter
from database import get_connection

router = APIRouter()

@router.get("/kpis")
def get_kpis():
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute("SELECT * FROM mv_dashboard_kpis;")
        return cur.fetchone()
        