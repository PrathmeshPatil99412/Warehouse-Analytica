from faker import Faker
import pandas as pd
from datetime import timedelta
from utils.constants import SO_STATUSES, SO_STATUS_WEIGHTS
from utils.random_dates import random_date, DATA_START, DATA_END

def generate(n: int, customer_ids, warehouse_ids, employee_ids, product_ids,
             unit_prices: dict, fake: Faker):
    so_rows, item_rows, item_id = [], [], 1
    for so_id in range(1, n + 1):
        order_date = random_date(DATA_START, DATA_END)
        status = fake.random_elements(elements=SO_STATUSES, length=1, weights=SO_STATUS_WEIGHTS)[0]
        ship_date = order_date + timedelta(days=fake.random_int(1, 5)) if status in ("shipped", "delivered") else None

        so_rows.append({
            "so_id": so_id,
            "customer_id": fake.random_element(customer_ids),
            "warehouse_id": fake.random_element(warehouse_ids),
            "employee_id": fake.random_element(employee_ids),
            "order_date": order_date.date(),
            "ship_date": ship_date.date() if ship_date else None,
            "status": status,
        })

        for _ in range(fake.random_int(1, 5)):
            product_id = fake.random_element(product_ids)
            item_rows.append({
                "so_item_id": item_id, "so_id": so_id, "product_id": product_id,
                "quantity": fake.random_int(1, 20),
                "unit_price": unit_prices[product_id],
                "discount_pct": fake.random_element([0, 0, 0, 5, 10, 15, 20]),
            })
            item_id += 1
    return pd.DataFrame(so_rows), pd.DataFrame(item_rows)