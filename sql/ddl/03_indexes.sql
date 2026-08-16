
-- COMPOSITE: queries filter by warehouse then date range constantly (Deliverable 5, query 11/12/16)
CREATE INDEX idx_movements_warehouse_date
    ON inventory_movements (warehouse_id, movement_date);

-- COMPOSITE: product+warehouse lookups on inventory (already UNIQUE, but this is the
-- general pattern — column order matters: put the more selective/most-filtered column first)
CREATE INDEX idx_soi_product_so
    ON sales_order_items (product_id, so_id);

-- PARTIAL: only index the "needs attention" subset — reorder queries never look at
-- fully-stocked rows, so don't waste index space/maintenance on them
CREATE INDEX idx_inventory_below_reorder
    ON inventory (product_id, warehouse_id)
    WHERE quantity_on_hand < 100;  -- tune threshold; illustrates the concept

-- PARTIAL: only active (non-cancelled) orders — most queries filter status != 'cancelled'
CREATE INDEX idx_sales_orders_active
    ON sales_orders (order_date, customer_id)
    WHERE status != 'cancelled';

-- PARTIAL: only 'received' POs for lead-time/late-delivery queries
CREATE INDEX idx_po_received
    ON purchase_orders (supplier_id, actual_delivery_date)
    WHERE status = 'received';

-- COVERING (INCLUDE): index-only scan for revenue queries — planner never touches
-- the heap because quantity/unit_price/discount_pct ride along in the index itself
CREATE INDEX idx_soi_covering_revenue
    ON sales_order_items (so_id) INCLUDE (product_id, quantity, unit_price, discount_pct);

-- COVERING: customer lookups that only need name+segment, not the full row
CREATE INDEX idx_customers_covering
    ON customers (customer_id) INCLUDE (name, segment);

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