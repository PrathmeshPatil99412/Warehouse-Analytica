import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://warehouse_admin:change_me@localhost:5432/warehouse_analytics")
SEED = int(os.getenv("SEED", 42))

VOLUMES = {
    "warehouses": int(os.getenv("NUM_WAREHOUSES", 10)),
    "products": int(os.getenv("NUM_PRODUCTS", 5000)),
    "suppliers": int(os.getenv("NUM_SUPPLIERS", 100)),
    "employees": int(os.getenv("NUM_EMPLOYEES", 300)),
    "customers": int(os.getenv("NUM_CUSTOMERS", 2000)),
    "sales_orders": int(os.getenv("NUM_SALES_ORDERS", 50000)),
    "purchase_orders": int(os.getenv("NUM_PURCHASE_ORDERS", 20000)),
    "inventory_movements": int(os.getenv("NUM_INVENTORY_MOVEMENTS", 200000)),
}

CSV_DIR = "data-generator/csv"