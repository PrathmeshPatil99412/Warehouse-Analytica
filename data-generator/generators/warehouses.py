from faker import Faker
import pandas as pd

def generate(n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        rows.append({
            "warehouse_id": i,
            "name": f"{fake.city()} Distribution Center",
            "address": fake.street_address(),
            "city": fake.city(),
            "state": fake.state(),
            "country": "United States",
            "capacity_units": fake.random_int(min=50000, max=500000),
        })
    return pd.DataFrame(rows)