import pandas as pd
from faker import Faker

def generate(product_ids: list, warehouse_ids: list, fake: Faker) -> pd.DataFrame:
    rows, inv_id = [], 1
    # not every product sits in every warehouse — realistic sparse coverage
    for product_id in product_ids:
        for warehouse_id in fake.random_elements(elements=warehouse_ids,
                                                    length=fake.random_int(1, len(warehouse_ids)),
                                                    unique=True):
            on_hand = fake.random_int(0, 2000)
            rows.append({
                "inventory_id": inv_id, "product_id": product_id, "warehouse_id": warehouse_id,
                "quantity_on_hand": on_hand,
                "quantity_reserved": fake.random_int(0, min(200, on_hand)) if on_hand else 0,
            })
            inv_id += 1
    return pd.DataFrame(rows)