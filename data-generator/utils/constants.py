PRODUCT_CATEGORIES = [
    ("Electronics", None), ("Home & Kitchen", None), ("Apparel", None),
    ("Sports & Outdoors", None), ("Toys & Games", None), ("Office Supplies", None),
    ("Automotive", None), ("Health & Beauty", None),
]
# Subcategories will get parent_category_id resolved at generation time
SUBCATEGORIES = {
    "Electronics": ["Audio", "Computers", "Mobile Accessories"],
    "Home & Kitchen": ["Cookware", "Furniture", "Storage"],
    "Apparel": ["Men", "Women", "Kids"],
}

CUSTOMER_SEGMENTS = ["retail", "wholesale", "online", "enterprise"]
SEGMENT_WEIGHTS = [0.45, 0.15, 0.30, 0.10]

PO_STATUSES = ["pending", "shipped", "received", "cancelled"]
PO_STATUS_WEIGHTS = [0.05, 0.10, 0.80, 0.05]

SO_STATUSES = ["pending", "shipped", "delivered", "cancelled"]
SO_STATUS_WEIGHTS = [0.05, 0.10, 0.80, 0.05]

MOVEMENT_TYPES = ["inbound", "outbound", "transfer_in", "transfer_out", "adjustment"]

JOB_TITLES = [
    "Warehouse Manager", "Inventory Clerk", "Forklift Operator", "Shipping Coordinator",
    "Receiving Associate", "Logistics Analyst", "Warehouse Supervisor", "Picker/Packer",
]