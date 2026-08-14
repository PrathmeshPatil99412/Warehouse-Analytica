CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT date_trunc('month', order_date) AS month, SUM(order_total) AS revenue, COUNT(*) AS order_count
FROM v_order_revenue WHERE status != 'cancelled'
GROUP BY 1
WITH DATA;
CREATE UNIQUE INDEX ON mv_monthly_sales (month);