-- ============================================================
-- MATERIALIZED VIEW: INVENTORY SNAPSHOT
-- ============================================================
--
-- Stores a precomputed snapshot of the inventory status used by
-- dashboard and analytical queries.
--
-- The underlying view contains the reusable inventory-status logic;
-- this materialized view trades freshness for faster repeated reads.
--
-- DESIGN DECISION:
-- Inventory status can be relatively expensive to derive repeatedly,
-- while dashboard reporting can tolerate controlled staleness.
-- Operational inventory checks should continue to query the base
-- inventory tables when real-time values are required.
-- ============================================================

CREATE MATERIALIZED VIEW mv_inventory_snapshot AS

SELECT product_id, warehouse_id, quantity_on_hand, quantity_available, needs_reorder

FROM v_inventory_status

WITH DATA;


-- ============================================================
-- Unique Index
-- ============================================================
--
-- Each product can have at most one inventory record per warehouse,
-- matching the UNIQUE(product_id, warehouse_id) business rule in
-- the underlying inventory table.
--
-- The unique index also provides an efficient lookup path for
-- product + warehouse snapshot queries.
--
-- It additionally satisfies the uniqueness requirement needed if
-- this materialized view is later refreshed CONCURRENTLY.
-- ============================================================

CREATE UNIQUE INDEX ON mv_inventory_snapshot (product_id, warehouse_id);