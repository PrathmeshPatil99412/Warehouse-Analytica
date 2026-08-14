# scripts/derive_movements.py
import os
import psycopg
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

SQL = """
-- inbound: every received PO line becomes an inbound movement
INSERT INTO inventory_movements (product_id, warehouse_id, movement_type, quantity, reference_id, reference_type, movement_date)
SELECT poi.product_id, po.warehouse_id, 'inbound', poi.quantity_received, poi.po_item_id, 'purchase_order', po.actual_delivery_date
FROM purchase_order_items poi
JOIN purchase_orders po ON po.po_id = poi.po_id
WHERE po.status = 'received' AND poi.quantity_received > 0;

-- outbound: every shipped/delivered SO line becomes an outbound movement
INSERT INTO inventory_movements (product_id, warehouse_id, movement_type, quantity, reference_id, reference_type, movement_date)
SELECT soi.product_id, so.warehouse_id, 'outbound', -soi.quantity, soi.so_item_id, 'sales_order', so.ship_date
FROM sales_order_items soi
JOIN sales_orders so ON so.so_id = soi.so_id
WHERE so.status IN ('shipped', 'delivered');

-- transfer_out / transfer_in: each completed transfer becomes a movement pair
INSERT INTO inventory_movements (product_id, warehouse_id, movement_type, quantity, reference_id, reference_type, movement_date)
SELECT product_id, from_warehouse_id, 'transfer_out', -quantity, transfer_id, 'transfer', transfer_date
FROM stock_transfers WHERE status = 'completed';

INSERT INTO inventory_movements (product_id, warehouse_id, movement_type, quantity, reference_id, reference_type, movement_date)
SELECT product_id, to_warehouse_id, 'transfer_in', quantity, transfer_id, 'transfer', transfer_date
FROM stock_transfers WHERE status = 'completed';
"""

def main():
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute(SQL)
        conn.commit()
    print("inventory_movements derived from orders + transfers.")

if __name__ == "__main__":
    main()