from faker import Faker
import pandas as pd
from datetime import timedelta
from utils.constants import PO_STATUSES, PO_STATUS_WEIGHTS
from utils.random_dates import random_date, DATA_START, DATA_END

def generate(n: int, supplier_ids, warehouse_ids, employee_ids, product_ids,
             unit_costs: dict, fake: Faker):
    po_rows, item_rows, item_id = [], [], 1
    for po_id in range(1, n + 1):
        order_date = random_date(DATA_START, DATA_END)
        status = fake.random_elements(elements=PO_STATUSES, length=1, weights=PO_STATUS_WEIGHTS)[0]
        expected = order_date + timedelta(days=fake.random_int(5, 21))
        actual = expected + timedelta(days=fake.random_int(-2, 10)) if status == "received" else None

        po_rows.append({
            "po_id": po_id,
            "supplier_id": fake.random_element(supplier_ids),
            "warehouse_id": fake.random_element(warehouse_ids),
            "employee_id": fake.random_element(employee_ids),
            "order_date": order_date.date(),
            "expected_delivery_date": expected.date(),
            "actual_delivery_date": actual.date() if actual else None,
            "status": status,
        })

        for _ in range(fake.random_int(1, 6)):
            product_id = fake.random_element(product_ids)
            qty_ordered = fake.random_int(10, 500)
            qty_received = qty_ordered if status == "received" else (
                fake.random_int(0, qty_ordered) if status == "shipped" else 0)
            item_rows.append({
                "po_item_id": item_id, "po_id": po_id, "product_id": product_id,
                "quantity_ordered": qty_ordered, "quantity_received": qty_received,
                "unit_cost": unit_costs[product_id],
            })
            item_id += 1
    return pd.DataFrame(po_rows), pd.DataFrame(item_rows)