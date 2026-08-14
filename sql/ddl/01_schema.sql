CREATE TABLE warehouses (
    warehouse_id    SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    address         VARCHAR(200),
    city            VARCHAR(100) NOT NULL,
    state           VARCHAR(100),
    country         VARCHAR(100) NOT NULL,
    capacity_units  INTEGER NOT NULL CHECK (capacity_units > 0),
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE employees (
    employee_id     SERIAL PRIMARY KEY,
    warehouse_id    INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    manager_id      INTEGER REFERENCES employees(employee_id),
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(150) UNIQUE NOT NULL,
    phone           VARCHAR(20),
    job_title       VARCHAR(100) NOT NULL,
    hire_date       DATE NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE product_categories (
    category_id         SERIAL PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    parent_category_id  INTEGER REFERENCES product_categories(category_id)
);

CREATE TABLE suppliers (
    supplier_id     SERIAL PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    contact_name    VARCHAR(100),
    email           VARCHAR(150),
    phone           VARCHAR(20),
    country         VARCHAR(100),
    rating          NUMERIC(2,1) CHECK (rating BETWEEN 0 AND 5),
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE products (
    product_id      SERIAL PRIMARY KEY,
    sku             VARCHAR(30) UNIQUE NOT NULL,
    name            VARCHAR(200) NOT NULL,
    category_id     INTEGER NOT NULL REFERENCES product_categories(category_id),
    supplier_id     INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    unit_cost       NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0),
    reorder_level   INTEGER NOT NULL DEFAULT 10,
    reorder_qty     INTEGER NOT NULL DEFAULT 50,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE customers (
    customer_id     SERIAL PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    email           VARCHAR(150) UNIQUE,
    phone           VARCHAR(20),
    address         VARCHAR(200),
    city            VARCHAR(100),
    country         VARCHAR(100),
    segment         VARCHAR(50) CHECK (segment IN ('retail','wholesale','online','enterprise')),
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE purchase_orders (
    po_id                   SERIAL PRIMARY KEY,
    supplier_id             INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    warehouse_id            INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    employee_id             INTEGER NOT NULL REFERENCES employees(employee_id),
    order_date              DATE NOT NULL,
    expected_delivery_date  DATE,
    actual_delivery_date    DATE,
    status                  VARCHAR(20) NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending','shipped','received','cancelled')),
    created_at              TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE purchase_order_items (
    po_item_id          SERIAL PRIMARY KEY,
    po_id                INTEGER NOT NULL REFERENCES purchase_orders(po_id) ON DELETE CASCADE,
    product_id           INTEGER NOT NULL REFERENCES products(product_id),
    quantity_ordered     INTEGER NOT NULL CHECK (quantity_ordered > 0),
    quantity_received    INTEGER NOT NULL DEFAULT 0 CHECK (quantity_received >= 0),
    unit_cost            NUMERIC(10,2) NOT NULL
);

CREATE TABLE sales_orders (
    so_id           SERIAL PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES customers(customer_id),
    warehouse_id    INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    employee_id     INTEGER NOT NULL REFERENCES employees(employee_id),
    order_date      DATE NOT NULL,
    ship_date       DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','shipped','delivered','cancelled')),
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE sales_order_items (
    so_item_id      SERIAL PRIMARY KEY,
    so_id           INTEGER NOT NULL REFERENCES sales_orders(so_id) ON DELETE CASCADE,
    product_id      INTEGER NOT NULL REFERENCES products(product_id),
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10,2) NOT NULL,
    discount_pct    NUMERIC(4,2) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100)
);

CREATE TABLE inventory (
    inventory_id        SERIAL PRIMARY KEY,
    product_id           INTEGER NOT NULL REFERENCES products(product_id),
    warehouse_id         INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    quantity_on_hand     INTEGER NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved    INTEGER NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    last_updated         TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (product_id, warehouse_id)
);

-- Partitioned by month on movement_date — see Deliverable 8 for partition creation
CREATE TABLE inventory_movements (
    movement_id     BIGSERIAL,
    product_id      INTEGER NOT NULL REFERENCES products(product_id),
    warehouse_id    INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    movement_type   VARCHAR(20) NOT NULL
                     CHECK (movement_type IN ('inbound','outbound','transfer_in','transfer_out','adjustment')),
    quantity        INTEGER NOT NULL,
    reference_id    INTEGER,        -- points to po_item_id / so_item_id / transfer_id depending on reference_type
    reference_type  VARCHAR(20),    -- 'purchase_order' | 'sales_order' | 'transfer' | 'adjustment'
    movement_date   TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (movement_id, movement_date)
) PARTITION BY RANGE (movement_date);

CREATE TABLE stock_transfers (
    transfer_id         SERIAL PRIMARY KEY,
    product_id           INTEGER NOT NULL REFERENCES products(product_id),
    from_warehouse_id    INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    to_warehouse_id      INTEGER NOT NULL REFERENCES warehouses(warehouse_id)
                          CHECK (to_warehouse_id != from_warehouse_id),
    employee_id          INTEGER NOT NULL REFERENCES employees(employee_id),
    quantity              INTEGER NOT NULL CHECK (quantity > 0),
    transfer_date          DATE NOT NULL,
    status                VARCHAR(20) NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','in_transit','completed','cancelled'))
);