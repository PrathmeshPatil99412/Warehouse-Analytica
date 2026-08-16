import psycopg
import time
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

QUERIES = {
    "dead_stock": """
        SELECT p.name, i.warehouse_id, i.quantity_on_hand
        FROM inventory i JOIN products p ON p.product_id = i.product_id
        WHERE i.quantity_on_hand > 0
          AND NOT EXISTS (
              SELECT 1 FROM inventory_movements im
              WHERE im.product_id = i.product_id AND im.warehouse_id = i.warehouse_id
                AND im.movement_type = 'outbound' AND im.movement_date > now() - interval '90 days'
          );
    """,
    "warehouse_movements_last_30d": """
        SELECT warehouse_id, COUNT(*) FROM inventory_movements
        WHERE warehouse_id = 3 AND movement_date > now() - interval '30 days'
        GROUP BY warehouse_id;
    """,
    "customer_ltv": """
        SELECT customer_id, name, lifetime_value FROM v_customer_ltv
        ORDER BY lifetime_value DESC LIMIT 20;
    """,
}

def explain_analyze(cur, label, sql):
    cur.execute(f"EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) {sql}")
    plan = "\n".join(row[0] for row in cur.fetchall())
    # pull execution time out of the plan text
    exec_line = [l for l in plan.splitlines() if "Execution Time" in l]
    print(f"--- {label} ---")
    print(exec_line[0] if exec_line else "Execution Time: not found")
    return plan

def main():
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            for label, sql in QUERIES.items():
                explain_analyze(cur, label, sql)
                print()

if __name__ == "__main__":
    main()