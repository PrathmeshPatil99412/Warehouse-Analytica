-- ============================================================
-- 1. Warehouses
-- ============================================================
--
-- Stores the master data for each physical warehouse.
--
-- warehouse_id is the surrogate primary key.
-- capacity_units represents the warehouse's configured storage
-- capacity for the analytical model.
--
-- BUSINESS CONSTRAINT:
-- capacity_units must be positive because a warehouse with zero
-- or negative capacity is invalid.
--
-- created_at provides record creation metadata.
-- ============================================================

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


-- ============================================================
-- 2. Employees
-- ============================================================
--
-- Stores employees assigned to warehouses.
--
-- warehouse_id establishes the employee's primary warehouse.
--
-- manager_id is a self-referencing foreign key that models the
-- organizational hierarchy:
--
--     employee -> manager -> manager's manager -> ...
--
-- email is UNIQUE to prevent duplicate employee identities.
--
-- BUSINESS USE:
-- The employee relationship is later used for order ownership,
-- operational reporting, and recursive organization-chart queries.
-- ============================================================

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


-- ============================================================
-- 3. Product Categories
-- ============================================================
--
-- Stores product classification data.
--
-- parent_category_id is a self-referencing foreign key, allowing
-- hierarchical categories such as:
--
--     Electronics
--       -> Computers
--          -> Laptops
--
-- This supports recursive category traversal and full-path
-- reporting.
-- ============================================================

CREATE TABLE product_categories (

    category_id         SERIAL PRIMARY KEY,

    name                VARCHAR(100) NOT NULL,

    parent_category_id  INTEGER REFERENCES product_categories(category_id)

);


-- ============================================================
-- 4. Suppliers
-- ============================================================
--
-- Stores supplier master data and supplier performance metadata.
--
-- rating is constrained to the business-defined range of 0 to 5.
--
-- Supplier attributes are kept separate from products so supplier
-- information is not duplicated across product records.
--
-- This separation supports normalized supplier-level analytics
-- such as spend, lead time, and delivery reliability.
-- ============================================================

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


-- ============================================================
-- 5. Products
-- ============================================================
--
-- Stores the product master/catalog data.
--
-- sku is a business identifier and is enforced as UNIQUE, while
-- product_id remains the surrogate primary key used for
-- relationships.
--
-- category_id and supplier_id establish product ownership within
-- the category and supplier dimensions.
--
-- unit_price represents the current selling price.
-- unit_cost represents the current acquisition cost.
--
-- reorder_level and reorder_qty support inventory replenishment
-- analysis.
--
-- BUSINESS NOTE:
-- Historical transaction prices are stored separately in
-- sales_order_items.unit_price and purchase_order_items.unit_cost,
-- preserving the price/cost used for individual transactions.
-- ============================================================

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


-- ============================================================
-- 6. Customers
-- ============================================================
--
-- Stores customer master data and segmentation attributes.
--
-- segment provides a controlled set of business customer types:
-- retail, wholesale, online, and enterprise.
--
-- email is UNIQUE when present, while remaining nullable to allow
-- customers without an email address.
--
-- BUSINESS USE:
-- Customer segmentation is later used for revenue-share,
-- lifetime-value, churn-risk, and RFM-style analysis.
-- ============================================================

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


-- ============================================================
-- 7. Purchase Orders
-- ============================================================
--
-- Represents the purchase-order header/master record.
--
-- Each purchase order belongs to:
--     supplier  -> who supplies the goods
--     warehouse -> where goods are received
--     employee  -> employee responsible for the transaction
--
-- Dates support supplier lead-time and delivery-performance
-- analysis.
--
-- status represents the lifecycle of the purchase order.
--
-- This table intentionally stores order-level information while
-- product-specific quantities and costs are kept in
-- purchase_order_items.
--
-- MODELING PATTERN:
-- Header-detail relationship with purchase_order_items.
-- ============================================================

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


-- ============================================================
-- 8. Purchase Order Items
-- ============================================================
--
-- Represents individual product lines within a purchase order.
--
-- A single purchase order can therefore contain multiple products
-- without repeating order-level information.
--
-- quantity_ordered records the requested quantity, while
-- quantity_received records the quantity actually received.
--
-- unit_cost is stored at transaction-line level so historical
-- procurement cost is preserved even if the product's current
-- cost changes later.
--
-- ON DELETE CASCADE ensures order items do not remain after their
-- parent purchase order is deleted.
--
-- MODELING PATTERN:
-- Detail/line-item table for the purchase-order header.
-- ============================================================

CREATE TABLE purchase_order_items (

    po_item_id          SERIAL PRIMARY KEY,

    po_id               INTEGER NOT NULL REFERENCES purchase_orders(po_id) ON DELETE CASCADE,

    product_id          INTEGER NOT NULL REFERENCES products(product_id),

    quantity_ordered    INTEGER NOT NULL CHECK (quantity_ordered > 0),

    quantity_received   INTEGER NOT NULL DEFAULT 0 CHECK (quantity_received >= 0),

    unit_cost           NUMERIC(10,2) NOT NULL

);


-- ============================================================
-- 9. Sales Orders
-- ============================================================
--
-- Represents the sales-order header/master record.
--
-- Each order identifies:
--     customer  -> who placed the order
--     warehouse -> warehouse fulfilling the order
--     employee  -> employee handling the order
--
-- The lifecycle is represented through the controlled status
-- values pending, shipped, delivered, and cancelled.
--
-- Product-specific quantities, prices, and discounts are stored
-- separately in sales_order_items.
--
-- MODELING PATTERN:
-- Header-detail relationship with sales_order_items.
-- ============================================================

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


-- ============================================================
-- 10. Sales Order Items
-- ============================================================
--
-- Represents individual product lines within a sales order.
--
-- quantity, unit_price, and discount_pct are transaction-level
-- attributes rather than product-master attributes.
--
-- This preserves the commercial terms applied when the sale
-- occurred, independent of future changes to products.unit_price.
--
-- discount_pct is constrained to the valid percentage range
-- 0–100.
--
-- ON DELETE CASCADE keeps line items dependent on their parent
-- sales order.
-- ============================================================

CREATE TABLE sales_order_items (

    so_item_id      SERIAL PRIMARY KEY,

    so_id           INTEGER NOT NULL REFERENCES sales_orders(so_id) ON DELETE CASCADE,

    product_id      INTEGER NOT NULL REFERENCES products(product_id),

    quantity        INTEGER NOT NULL CHECK (quantity > 0),

    unit_price      NUMERIC(10,2) NOT NULL,

    discount_pct    NUMERIC(4,2) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100)

);


-- ============================================================
-- 11. Inventory
-- ============================================================
--
-- Represents the current inventory state for each
-- product/warehouse combination.
--
-- quantity_on_hand  -> physical stock currently held
-- quantity_reserved -> stock committed to pending demand
--
-- UNIQUE(product_id, warehouse_id) ensures there is only one
-- current inventory record for a given product at a warehouse.
--
-- This table is intentionally state-oriented; historical changes
-- are captured separately in inventory_movements.
--
-- MODELING PATTERN:
-- Associative entity between products and warehouses with
-- relationship-specific attributes such as quantity and reservation.
-- ============================================================

CREATE TABLE inventory (

    inventory_id        SERIAL PRIMARY KEY,

    product_id          INTEGER NOT NULL REFERENCES products(product_id),

    warehouse_id        INTEGER NOT NULL REFERENCES warehouses(warehouse_id),

    quantity_on_hand    INTEGER NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),

    quantity_reserved   INTEGER NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),

    last_updated        TIMESTAMP NOT NULL DEFAULT now(),

    UNIQUE (product_id, warehouse_id)

);


-- ============================================================
-- 12. Inventory Movements
-- ============================================================
--
-- Event/history table recording changes to inventory over time.
--
-- Each movement identifies the product, warehouse, movement type,
-- quantity, and timestamp.
--
-- Supported movement types:
--     inbound
--     outbound
--     transfer_in
--     transfer_out
--     adjustment
--
-- reference_id/reference_type provide contextual linkage back to
-- the business transaction that caused the movement.
--
-- The table is partitioned by movement_date because movement
-- history is naturally time-oriented and can grow significantly.
--
-- COMPOSITE PRIMARY KEY:
--     (movement_id, movement_date)
--
-- movement_date is included because PostgreSQL requires the
-- partitioning column to be part of a unique/primary-key constraint
-- on a partitioned table.
--
-- DESIGN NOTE:
-- reference_id/reference_type form a polymorphic reference and
-- therefore cannot provide a conventional FK to multiple possible
-- parent tables.
-- ============================================================

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


-- ============================================================
-- 13. Stock Transfers
-- ============================================================
--
-- Represents movement of a product between two warehouses.
--
-- from_warehouse_id and to_warehouse_id represent two distinct
-- roles for the warehouses, making this a role-based relationship.
--
-- The CHECK constraint prevents a warehouse from transferring
-- stock to itself.
--
-- employee_id records the employee responsible for the transfer.
--
-- status represents the transfer lifecycle.
--
-- BUSINESS USE:
-- This table acts as the business transaction record, while
-- inventory_movements records the corresponding inventory events
-- at both the source and destination warehouses.
-- ============================================================

CREATE TABLE stock_transfers (

    transfer_id         SERIAL PRIMARY KEY,

    product_id          INTEGER NOT NULL REFERENCES products(product_id),

    from_warehouse_id   INTEGER NOT NULL REFERENCES warehouses(warehouse_id),

    to_warehouse_id     INTEGER NOT NULL REFERENCES warehouses(warehouse_id)
                         CHECK (to_warehouse_id != from_warehouse_id),

    employee_id         INTEGER NOT NULL REFERENCES employees(employee_id),

    quantity            INTEGER NOT NULL CHECK (quantity > 0),

    transfer_date       DATE NOT NULL,

    status              VARCHAR(20) NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending','in_transit','completed','cancelled'))

);