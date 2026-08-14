# data-generator/generators/employees.py
from faker import Faker
import pandas as pd
from utils.constants import JOB_TITLES
from utils.random_dates import random_date, DATA_START, DATA_END

def generate(n: int, warehouse_ids: list, fake: Faker) -> pd.DataFrame:
    rows = []
    manager_pool = []  # employee_ids eligible to be managers, filled progressively
    for i in range(1, n + 1):
        # first employee per warehouse batch has no manager (acts as warehouse manager)
        is_manager_slot = (i - 1) % 30 == 0
        manager_id = None if is_manager_slot or not manager_pool else fake.random_element(manager_pool)
        rows.append({
            "employee_id": i,
            "warehouse_id": fake.random_element(warehouse_ids),
            "manager_id": manager_id,
            "first_name": fake.first_name(),
            "last_name": fake.last_name(),
            "email": fake.unique.email(),
            "phone": fake.phone_number()[:20],
            "job_title": "Warehouse Manager" if is_manager_slot else fake.random_element(JOB_TITLES[1:]),
            "hire_date": random_date(DATA_START, DATA_END).date(),
        })
        if is_manager_slot:
            manager_pool.append(i)
    df = pd.DataFrame(rows)
    df["manager_id"] = df["manager_id"].astype("Int64")  # nullable int, avoids float bug
    return df