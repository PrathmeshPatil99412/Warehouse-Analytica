-- ============================================================
-- MATERIALIZED VIEW: SUPPLIER METRICS
-- ============================================================
--
-- Consolidates supplier operational and financial metrics into a
-- single precomputed reporting layer.
--
-- Combines:
--     • Supplier rating
--     • Average delivery lead time
--     • On-time delivery percentage
--     • Total supplier spend
--
-- Result grain:
--     One row per supplier.
--
-- DESIGN DECISION:
-- The underlying views separately encapsulate supplier performance
-- and spending logic. This materialized view combines those metrics
-- so supplier dashboards and reports do not need to repeatedly
-- execute the underlying aggregations and joins.
-- ============================================================

CREATE MATERIALIZED VIEW mv_supplier_metrics AS

SELECT sp.supplier_id, sp.name, sp.rating, sp.avg_lead_time_days, sp.on_time_pct, sv.total_spend

FROM v_supplier_performance sp

JOIN v_supplier_spend sv ON sv.supplier_id = sp.supplier_id

WITH DATA;


-- ============================================================
-- Unique Index on Supplier Grain
-- ============================================================
--
-- The result contains at most one row per supplier, making
-- supplier_id the natural unique key for this materialized view.
--
-- The index also provides efficient supplier-level lookups and
-- enables REFRESH MATERIALIZED VIEW CONCURRENTLY if the view is
-- refreshed using that strategy.
-- ============================================================

CREATE UNIQUE INDEX ON mv_supplier_metrics (supplier_id);