from faker import Faker
import pandas as pd
from config import SEED, VOLUMES, CSV_DIR
from utils.helpers import save_csv
from generators import warehouses, employees, suppliers, products, customers
from generators import purchase_orders, sales_orders, inventory, transfers

fake = Faker()
Faker.seed(SEED)

print("Generating warehouses..."); wh_df = warehouses.generate(VOLUMES["warehouses"], fake)
save_csv(wh_df, "warehouses", CSV_DIR)

print("Generating employees..."); emp_df = employees.generate(VOLUMES["employees"], wh_df.warehouse_id.tolist(), fake)
save_csv(emp_df, "employees", CSV_DIR)

print("Generating suppliers..."); sup_df = suppliers.generate(VOLUMES["suppliers"], fake)
save_csv(sup_df, "suppliers", CSV_DIR)

print("Generating categories..."); cat_df = products.generate_categories(fake)
save_csv(cat_df, "product_categories", CSV_DIR)

print("Generating products...")
prod_df = products.generate_products(VOLUMES["products"], cat_df.category_id.tolist(), sup_df.supplier_id.tolist(), fake)
save_csv(prod_df, "products", CSV_DIR)

print("Generating customers..."); cust_df = customers.generate(VOLUMES["customers"], fake)
save_csv(cust_df, "customers", CSV_DIR)

unit_costs = prod_df.set_index("product_id")["unit_cost"].to_dict()
unit_prices = prod_df.set_index("product_id")["unit_price"].to_dict()

print("Generating purchase orders...")
po_df, po_items_df = purchase_orders.generate(
    VOLUMES["purchase_orders"], sup_df.supplier_id.tolist(), wh_df.warehouse_id.tolist(),
    emp_df.employee_id.tolist(), prod_df.product_id.tolist(), unit_costs, fake)
save_csv(po_df, "purchase_orders", CSV_DIR); save_csv(po_items_df, "purchase_order_items", CSV_DIR)

print("Generating sales orders...")
so_df, so_items_df = sales_orders.generate(
    VOLUMES["sales_orders"], cust_df.customer_id.tolist(), wh_df.warehouse_id.tolist(),
    emp_df.employee_id.tolist(), prod_df.product_id.tolist(), unit_prices, fake)
save_csv(so_df, "sales_orders", CSV_DIR); save_csv(so_items_df, "sales_order_items", CSV_DIR)

print("Generating inventory snapshot...")
inv_df = inventory.generate(prod_df.product_id.tolist(), wh_df.warehouse_id.tolist(), fake)
save_csv(inv_df, "inventory", CSV_DIR)

print("Generating stock transfers...")
# stock_transfers count derived from inventory_movements budget (transfers ~10% of movements)
transfer_n = VOLUMES["inventory_movements"] // 10
trans_df = transfers.generate(transfer_n, prod_df.product_id.tolist(), wh_df.warehouse_id.tolist(),
                                emp_df.employee_id.tolist(), fake)
save_csv(trans_df, "stock_transfers", CSV_DIR)

print("\nAll CSVs generated in", CSV_DIR)