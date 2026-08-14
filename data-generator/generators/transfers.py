from faker import Faker
import pandas as pd
from utils.random_dates import random_date, DATA_START, DATA_END

def generate(n: int, product_ids, warehouse_ids, employee_ids, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        from_wh, to_wh = fake.random_elements(elements=warehouse_ids, length=2, unique=True)
        rows.append({
            "transfer_id": i,
            "product_id": fake.random_element(product_ids),
            "from_warehouse_id": from_wh,
            "to_warehouse_id": to_wh,
            "employee_id": fake.random_element(employee_ids),
            "quantity": fake.random_int(10, 300),
            "transfer_date": random_date(DATA_START, DATA_END).date(),
            "status": fake.random_element(["completed"] * 8 + ["in_transit", "cancelled"]),
        })
    return pd.DataFrame(rows)