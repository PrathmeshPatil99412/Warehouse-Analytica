import psycopg
import pandas as pd
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
CSV_DIR = "data-generator/csv"

# Load order matters: parents before children (FK dependency order)
LOAD_ORDER = [
    "warehouses", "product_categories", "suppliers", "employees",
    "products", "customers", "purchase_orders", "purchase_order_items",
    "sales_orders", "sales_order_items", "inventory", "stock_transfers",
]

def load_table(cur, table: str):
    path = f"{CSV_DIR}/{table}.csv"
    with open(path, "r") as f:
        header = f.readline().strip()
        columns = header  # CSV header is already comma-separated column names
        with cur.copy(f"COPY {table} ({columns}) FROM STDIN WITH (FORMAT csv, HEADER false, NULL '')") as copy:
            while data := f.read(8192):
                copy.write(data)
    print(f"  loaded {table}")

def reset_sequences(cur):
    # after COPY with explicit IDs, sequences need bumping to max(id)+1
    seq_map = {
        "warehouses": "warehouse_id", "employees": "employee_id", "suppliers": "supplier_id",
        "product_categories": "category_id", "products": "product_id", "customers": "customer_id",
        "purchase_orders": "po_id", "purchase_order_items": "po_item_id",
        "sales_orders": "so_id", "sales_order_items": "so_item_id",
        "inventory": "inventory_id", "stock_transfers": "transfer_id",
    }
    for table, pk in seq_map.items():
        cur.execute(f"SELECT setval(pg_get_serial_sequence('{table}', '{pk}'), COALESCE(MAX({pk}), 1)) FROM {table};")

def main():
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            for table in LOAD_ORDER:
                load_table(cur, table)
            reset_sequences(cur)
        conn.commit()
    print("Database population complete.")

if __name__ == "__main__":
    main()