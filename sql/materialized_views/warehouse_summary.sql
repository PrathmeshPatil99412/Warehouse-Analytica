-- ============================================================
-- MATERIALIZED VIEW: WAREHOUSE SUMMARY
-- ============================================================
--
-- Consolidates key operational metrics for each warehouse into
-- a single precomputed reporting dataset.
--
-- Combines:
--     • Warehouse utilization
--     • Current inventory value
--     • Total sales orders handled
--
-- Result grain:
--     One row per warehouse.
--
-- DESIGN DECISION:
-- These metrics are derived from separate reusable views because
-- each metric has its own business logic. This materialized view
-- provides a single reporting layer for warehouse-level dashboards
-- without repeatedly executing the underlying aggregations.
-- ============================================================

CREATE MATERIALIZED VIEW mv_warehouse_summary AS

SELECT wu.warehouse_id, wu.name, wu.utilization_pct, iv.inventory_value, ep.total_orders

FROM v_warehouse_utilization wu

-- Add the monetary value of inventory currently held by the warehouse.
JOIN v_inventory_value_by_warehouse iv ON iv.warehouse_id = wu.warehouse_id

-- Aggregate employee-level order counts to the warehouse level
-- before joining, ensuring the final result remains one row per warehouse.
JOIN (SELECT warehouse_id, SUM(orders_handled) AS total_orders FROM v_employee_productivity GROUP BY warehouse_id) ep

    ON ep.warehouse_id = wu.warehouse_id

WITH DATA;


-- ============================================================
-- Unique Index on Warehouse Grain
-- ============================================================
--
-- warehouse_id uniquely identifies each row in this materialized
-- view because all three metrics are aggregated at warehouse level.
--
-- The index supports efficient warehouse-level lookups and also
-- satisfies the uniqueness requirement for a potential
-- REFRESH MATERIALIZED VIEW CONCURRENTLY strategy.
-- ============================================================

CREATE UNIQUE INDEX ON mv_warehouse_summary (warehouse_id);