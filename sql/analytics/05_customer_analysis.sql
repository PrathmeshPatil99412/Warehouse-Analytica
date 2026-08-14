-- 26. Top 20 customers by lifetime value
SELECT c.name, SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS lifetime_value
FROM customers c
JOIN sales_orders so ON so.customer_id = c.customer_id AND so.status != 'cancelled'
JOIN sales_order_items soi ON soi.so_id = so.so_id
GROUP BY c.name ORDER BY lifetime_value DESC LIMIT 20;

-- 27. Customer segment revenue share
SELECT c.segment, SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue,
       ROUND(100.0 * SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0))
             / SUM(SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0))) OVER (), 2) AS pct
FROM customers c
JOIN sales_orders so ON so.customer_id = c.customer_id AND so.status != 'cancelled'
JOIN sales_order_items soi ON soi.so_id = so.so_id
GROUP BY c.segment ORDER BY revenue DESC;

-- 28. Customers with no orders in the last 6 months (churn risk) — correlated subquery
SELECT c.customer_id, c.name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM sales_orders so
    WHERE so.customer_id = c.customer_id AND so.order_date > now() - interval '6 months'
)
LIMIT 50;

-- 29. Customer order frequency distribution
SELECT order_count_bucket, COUNT(*) AS num_customers FROM (
    SELECT c.customer_id,
           CASE WHEN COUNT(so.so_id) = 0 THEN '0'
                WHEN COUNT(so.so_id) BETWEEN 1 AND 3 THEN '1-3'
                WHEN COUNT(so.so_id) BETWEEN 4 AND 10 THEN '4-10'
                ELSE '10+' END AS order_count_bucket
    FROM customers c LEFT JOIN sales_orders so ON so.customer_id = c.customer_id
    GROUP BY c.customer_id
) t GROUP BY order_count_bucket ORDER BY order_count_bucket;

-- 30. RFM-style: Recency, Frequency, Monetary per customer
SELECT c.customer_id, c.name,
       now()::date - MAX(so.order_date) AS recency_days,
       COUNT(DISTINCT so.so_id) AS frequency,
       SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS monetary
FROM customers c
JOIN sales_orders so ON so.customer_id = c.customer_id AND so.status != 'cancelled'
JOIN sales_order_items soi ON soi.so_id = so.so_id
GROUP BY c.customer_id, c.name
LIMIT 50;