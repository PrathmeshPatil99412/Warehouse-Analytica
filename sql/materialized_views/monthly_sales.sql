-- ============================================================
-- MATERIALIZED VIEW: MONTHLY SALES SUMMARY
-- ============================================================
--
-- Precomputes monthly revenue and order volume from the reusable
-- order-revenue view.
--
-- Result grain:
--     One row per calendar month.
--
-- DESIGN DECISION:
-- Monthly sales is an analytical/reporting metric rather than a
-- real-time operational metric, so storing the aggregated result
-- avoids repeatedly recalculating revenue across order-level data.
-- Cancelled orders are excluded to keep the KPI aligned with the
-- project's revenue reporting logic.
-- ============================================================

CREATE MATERIALIZED VIEW mv_monthly_sales AS

SELECT date_trunc('month', order_date) AS month, SUM(order_total) AS revenue, COUNT(*) AS order_count

FROM v_order_revenue WHERE status != 'cancelled'

GROUP BY 1

WITH DATA;


-- ============================================================
-- Unique Index on Monthly Grain
-- ============================================================
--
-- Since the materialized view produces exactly one row per month,
-- month is the natural unique key for this result set.
--
-- The index also provides efficient month-based lookups and enables
-- REFRESH MATERIALIZED VIEW CONCURRENTLY if a suitable refresh
-- strategy is adopted.
-- ============================================================

CREATE UNIQUE INDEX ON mv_monthly_sales (month);