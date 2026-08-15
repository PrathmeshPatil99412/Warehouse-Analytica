-- Procedure: Refresh all materialized views (called by FastAPI's /analytics/refresh-materialized-views)
CREATE OR REPLACE PROCEDURE sp_refresh_dashboard()
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_snapshot;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_supplier_metrics;
    REFRESH MATERIALIZED VIEW mv_dashboard_kpis;   -- no unique index → can't use CONCURRENTLY
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_warehouse_summary;
    RAISE NOTICE 'Dashboard materialized views refreshed at %', now();
END;
$$;