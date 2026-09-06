-- ============================================================
-- MATERIALIZED VIEW: EXECUTIVE DASHBOARD KPIs
-- ============================================================
--
-- Precomputes the core KPIs required by the dashboard into a
-- single-row snapshot.
--
-- The underlying views contain the reusable business logic,
-- while this materialized view acts as the performance-oriented
-- reporting layer.
--
-- KPIs included:
--     • Revenue generated in the last 30 days
--     • Current total inventory value
--     • Products below reorder threshold
--     • Average supplier lead time
--     • Timestamp of the snapshot
--
-- DESIGN DECISION:
-- These metrics are appropriate for a materialized view because
-- they aggregate data across multiple tables/views and are
-- primarily used for dashboard/reporting purposes, where slight
-- staleness between refreshes is acceptable.
-- ============================================================

CREATE MATERIALIZED VIEW mv_dashboard_kpis AS

SELECT

    -- Rolling 30-day revenue from the reusable daily-revenue view.
    -- NULL is possible when there is no qualifying revenue.
    (SELECT SUM(revenue) FROM v_daily_revenue WHERE order_date > now() - interval '30 days') AS revenue_30d,

    -- Current inventory valuation aggregated across all warehouses.
    (SELECT SUM(inventory_value) FROM v_inventory_value_by_warehouse) AS total_inventory_value,

    -- Count of product/warehouse inventory records currently
    -- flagged as requiring replenishment.
    (SELECT COUNT(*) FROM mv_inventory_snapshot WHERE needs_reorder) AS products_below_reorder,

    -- Average supplier lead time derived from received purchase
    -- order performance.
    (SELECT ROUND(AVG(avg_lead_time_days), 1) FROM v_supplier_performance) AS avg_supplier_lead_time,

    -- Records when this dashboard snapshot was generated/refreshed.
    now() AS refreshed_at

WITH DATA;