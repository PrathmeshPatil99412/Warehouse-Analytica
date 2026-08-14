from faker import Faker
import pandas as pd
from utils.constants import PRODUCT_CATEGORIES, SUBCATEGORIES

def generate_categories(fake: Faker) -> pd.DataFrame:
    rows, cat_id = [], 1
    parent_id_map = {}
    for name, _ in PRODUCT_CATEGORIES:
        rows.append({"category_id": cat_id, "name": name, "parent_category_id": None})
        parent_id_map[name] = cat_id
        cat_id += 1
    for parent, children in SUBCATEGORIES.items():
        for child in children:
            rows.append({"category_id": cat_id, "name": child, "parent_category_id": parent_id_map[parent]})
            cat_id += 1
    return pd.DataFrame(rows)

def generate_products(n: int, category_ids: list, supplier_ids: list, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        cost = round(fake.pyfloat(min_value=2, max_value=500, right_digits=2), 2)
        price = round(cost * fake.pyfloat(min_value=1.2, max_value=2.5, right_digits=2), 2)
        rows.append({
            "product_id": i,
            "sku": f"SKU-{i:06d}",
            "name": fake.catch_phrase(),
            "category_id": fake.random_element(category_ids),
            "supplier_id": fake.random_element(supplier_ids),
            "unit_price": price,
            "unit_cost": cost,
            "reorder_level": fake.random_int(5, 50),
            "reorder_qty": fake.random_int(50, 200),
        })
    return pd.DataFrame(rows)