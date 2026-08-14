from faker import Faker
import pandas as pd
from utils.constants import CUSTOMER_SEGMENTS, SEGMENT_WEIGHTS
import random

def generate(n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        rows.append({
            "customer_id": i,
            "name": fake.name() if fake.boolean(chance_of_getting_true=60) else fake.company(),
            "email": fake.unique.email(),
            "phone": fake.phone_number()[:20],
            "address": fake.street_address(),
            "city": fake.city(),
            "country": fake.country(),
            "segment": random.choices(CUSTOMER_SEGMENTS, weights=SEGMENT_WEIGHTS)[0],
        })
    return pd.DataFrame(rows)