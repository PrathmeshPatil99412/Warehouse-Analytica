from faker import Faker
import pandas as pd

def generate(n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        rows.append({
            "supplier_id": i,
            "name": fake.company(),
            "contact_name": fake.name(),
            "email": fake.unique.company_email(),
            "phone": fake.phone_number()[:20],
            "country": fake.country(),
            "rating": round(fake.pyfloat(min_value=2.0, max_value=5.0, right_digits=1), 1),
        })
    return pd.DataFrame(rows)