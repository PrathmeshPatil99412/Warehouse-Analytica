-- ============================================================
-- PROCEDURE: REFRESH DASHBOARD MATERIALIZED VIEWS
-- ============================================================
--
-- Centralizes the refresh workflow for the project's analytical
-- materialized views behind a single database procedure.
--
-- This allows the application layer to trigger the complete
-- analytics refresh through one database call instead of managing
-- each materialized view independently.
--
-- CONCURRENTLY is used where a suitable unique index exists so
-- readers can continue accessing the materialized view during
-- refresh.
-- ============================================================

-- Procedure: Refresh all materialized views (called by FastAPI's /analytics/refresh-materialized-views)

CREATE OR REPLACE PROCEDURE sp_refresh_dashboard()

LANGUAGE plpgsql AS $$

BEGIN

    -- Refresh monthly sales while allowing concurrent readers.
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;

    -- Refresh the inventory reporting snapshot.
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_snapshot;

    -- Refresh consolidated supplier performance metrics.
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_supplier_metrics;

    -- Dashboard KPI view has no unique index, so PostgreSQL does not
    -- allow CONCURRENTLY for this materialized view.
    REFRESH MATERIALIZED VIEW mv_dashboard_kpis;   -- no unique index → can't use CONCURRENTLY

    -- Refresh the warehouse-level reporting summary.
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_warehouse_summary;

    -- Confirm completion and record the refresh timestamp.
    RAISE NOTICE 'Dashboard materialized views refreshed at %', now();

END;

$$;