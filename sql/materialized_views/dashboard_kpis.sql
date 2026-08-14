CREATE MATERIALIZED VIEW mv_dashboard_kpis AS
SELECT
    (SELECT SUM(revenue) FROM v_daily_revenue WHERE order_date > now() - interval '30 days') AS revenue_30d,
    (SELECT SUM(inventory_value) FROM v_inventory_value_by_warehouse) AS total_inventory_value,
    (SELECT COUNT(*) FROM mv_inventory_snapshot WHERE needs_reorder) AS products_below_reorder,
    (SELECT ROUND(AVG(avg_lead_time_days), 1) FROM v_supplier_performance) AS avg_supplier_lead_time,
    now() AS refreshed_at
WITH DATA;