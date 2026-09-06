-- ============================================================
-- INDEXING STRATEGY
-- ============================================================
--
-- Indexes are targeted around the project's common access patterns:
--     • warehouse/date filtering on movement history
--     • product/warehouse inventory lookups
--     • active and received transaction subsets
--     • covering analytical queries
--     • foreign-key joins
--
-- The goal is not to index every column, but to support the
-- high-frequency filtering and join paths used by the analytical
-- workload while controlling index storage and write overhead.
-- ============================================================


-- ============================================================
-- 1. Composite Index — Warehouse + Movement Date
-- ============================================================
--
-- Supports frequent queries that first restrict movements to a
-- warehouse and then apply a date range.
--
-- Composite column order follows the expected filtering pattern:
--     warehouse_id -> movement_date
--
-- This is particularly relevant for the movement-history queries
-- that analyze recent activity at a specific warehouse.
-- ============================================================

-- COMPOSITE: queries filter by warehouse then date range constantly (Deliverable 5, query 11/12/16)

CREATE INDEX idx_movements_warehouse_date

    ON inventory_movements (warehouse_id, movement_date);


-- ============================================================
-- 2. Composite Index — Product + Sales Order
-- ============================================================
--
-- Supports product-level sales-order-item lookups where product_id
-- is the primary filtering dimension and so_id provides the
-- associated order relationship.
--
-- The column order is intentional: product_id is the leading
-- column for product-driven access patterns.
--
-- DESIGN NOTE:
-- inventory already has a UNIQUE(product_id, warehouse_id)
-- constraint, which creates an index supporting that exact
-- uniqueness/access pattern. This index targets a different
-- sales_order_items workload.
-- ============================================================

-- COMPOSITE: product+warehouse lookups on inventory (already UNIQUE, but this is the
-- general pattern — column order matters: put the more selective/most-filtered column first)

CREATE INDEX idx_soi_product_so

    ON sales_order_items (product_id, so_id);


-- ============================================================
-- 3. Partial Index — Inventory Below Reorder Threshold
-- ============================================================
--
-- Indexes only inventory rows currently below the configured
-- analytical threshold.
--
-- This reduces index size compared with indexing the complete
-- inventory table when the workload primarily targets
-- understocked inventory.
--
-- DESIGN NOTE:
-- The predicate uses a fixed value of 100 rather than the
-- product-specific reorder_level. Therefore this index directly
-- supports queries using the same predicate, but is not a general
-- index for every "quantity_on_hand < reorder_level" condition.
-- ============================================================

-- PARTIAL: only index the "needs attention" subset — reorder queries never look at
-- fully-stocked rows, so don't waste index space/maintenance on them

CREATE INDEX idx_inventory_below_reorder

    ON inventory (product_id, warehouse_id)

    WHERE quantity_on_hand < 100;  -- tune threshold; illustrates the concept


-- ============================================================
-- 4. Partial Index — Active Sales Orders
-- ============================================================
--
-- Restricts the index to non-cancelled orders because the analytical
-- workload frequently excludes cancelled transactions.
--
-- Leading with order_date supports time-based order analysis, while
-- customer_id supports customer-level access patterns.
--
-- Partial indexes are especially useful when the indexed subset is
-- significantly smaller than the complete table.
-- ============================================================

-- PARTIAL: only active (non-cancelled) orders — most queries filter status != 'cancelled'

CREATE INDEX idx_sales_orders_active

    ON sales_orders (order_date, customer_id)

    WHERE status != 'cancelled';


-- ============================================================
-- 5. Partial Index — Received Purchase Orders
-- ============================================================
--
-- Restricts the index to completed/received purchase orders.
--
-- Supports supplier lead-time and delivery-performance analysis
-- where status = 'received' is a consistent filtering condition.
--
-- supplier_id is the leading column because supplier-level
-- performance queries are a major access pattern.
-- ============================================================

-- PARTIAL: only 'received' POs for lead-time/late-delivery queries

CREATE INDEX idx_po_received

    ON purchase_orders (supplier_id, actual_delivery_date)

    WHERE status = 'received';


-- ============================================================
-- 6. Covering Index — Sales Revenue Queries
-- ============================================================
--
-- Includes the sales-order-item attributes required by revenue
-- calculations so the planner can potentially satisfy the query
-- directly from the index.
--
-- so_id remains the key column for locating order items, while
-- product_id, quantity, unit_price, and discount_pct are stored
-- as included payload columns.
--
-- INCLUDE columns are not part of the index ordering; they are
-- stored to support covering/index-only access patterns.
--
-- DESIGN NOTE:
-- An index-only scan is possible when PostgreSQL can also satisfy
-- visibility requirements through the visibility map. It is not
-- guaranteed for every execution.
-- ============================================================

-- COVERING (INCLUDE): index-only scan for revenue queries — planner never touches

-- the heap because quantity/unit_price/discount_pct ride along in the index itself

CREATE INDEX idx_soi_covering_revenue

    ON sales_order_items (so_id) INCLUDE (product_id, quantity, unit_price, discount_pct);


-- ============================================================
-- 7. Covering Index — Customer Lookup
-- ============================================================
--
-- Keeps commonly requested customer attributes available alongside
-- the primary-key index entry.
--
-- Useful when a query identifies customers by customer_id but only
-- needs name and segment rather than the complete customer row.
-- ============================================================

-- COVERING: customer lookups that only need name+segment, not the full row

CREATE INDEX idx_customers_covering

    ON customers (customer_id) INCLUDE (name, segment);


-- ============================================================
-- 8. Foreign-Key Support Indexes
-- ============================================================
--
-- PostgreSQL creates indexes automatically for PRIMARY KEY and
-- UNIQUE constraints, but it does NOT automatically create indexes
-- on the referencing side of foreign keys.
--
-- These indexes support common parent/child joins, filtering, and
-- referential actions involving the corresponding FK columns.
--
-- INTERVIEW NOTE:
-- This is an important PostgreSQL indexing consideration: foreign
-- keys enforce referential integrity, but the FK column itself is
-- not automatically indexed.
-- ============================================================

-- Standard FK-support indexes (Postgres does NOT auto-index FK columns — a very
-- common interview gotcha)

CREATE INDEX idx_soi_product ON sales_order_items (product_id);

CREATE INDEX idx_poi_product ON purchase_order_items (product_id);

CREATE INDEX idx_so_customer ON sales_orders (customer_id);

CREATE INDEX idx_so_warehouse ON sales_orders (warehouse_id);

CREATE INDEX idx_so_employee ON sales_orders (employee_id);

CREATE INDEX idx_po_supplier ON purchase_orders (supplier_id);

CREATE INDEX idx_products_category ON products (category_id);

CREATE INDEX idx_products_supplier ON products (supplier_id);

CREATE INDEX idx_employees_manager ON employees (manager_id);

CREATE INDEX idx_transfers_from_wh ON stock_transfers (from_warehouse_id);

CREATE INDEX idx_transfers_to_wh ON stock_transfers (to_warehouse_id);