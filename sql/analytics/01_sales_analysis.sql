-- 1. Total revenue by month
SELECT date_trunc('month', so.order_date) AS month,
       SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue
FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
WHERE so.status != 'cancelled'
GROUP BY 1 ORDER BY 1;

-- 2. Month-over-month growth %
WITH monthly AS (
    SELECT date_trunc('month', so.order_date) AS month,
           SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue
    FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
    WHERE so.status != 'cancelled'
    GROUP BY 1
)
SELECT month, revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month)) / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM monthly ORDER BY month;

-- 3. Year-over-year growth %
WITH monthly AS (
    SELECT date_trunc('month', so.order_date) AS month,
           SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue
    FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
    WHERE so.status != 'cancelled'
    GROUP BY 1
)
SELECT month, revenue,
       ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (ORDER BY month)) / NULLIF(LAG(revenue, 12) OVER (ORDER BY month), 0), 2) AS yoy_growth_pct
FROM monthly ORDER BY month;

-- 4. Running total revenue (YTD)
SELECT month, revenue,
       SUM(revenue) OVER (PARTITION BY date_trunc('year', month) ORDER BY month) AS ytd_running_total
FROM (
    SELECT date_trunc('month', so.order_date) AS month,
           SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue
    FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
    WHERE so.status != 'cancelled' GROUP BY 1
) t ORDER BY month;

-- 5. Revenue by product category
SELECT pc.name AS category, SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue
FROM sales_order_items soi
JOIN products p ON p.product_id = soi.product_id
JOIN product_categories pc ON pc.category_id = p.category_id
JOIN sales_orders so ON so.so_id = soi.so_id AND so.status != 'cancelled'
GROUP BY pc.name ORDER BY revenue DESC;

-- 6. Average order value by customer segment
SELECT c.segment, ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
    SELECT so.so_id, so.customer_id, SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS order_total
    FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
    WHERE so.status != 'cancelled' GROUP BY so.so_id, so.customer_id
) o JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.segment ORDER BY avg_order_value DESC;

-- 7. Best-selling products by quantity
SELECT p.name, SUM(soi.quantity) AS units_sold
FROM sales_order_items soi JOIN products p ON p.product_id = soi.product_id
JOIN sales_orders so ON so.so_id = soi.so_id AND so.status != 'cancelled'
GROUP BY p.name ORDER BY units_sold DESC LIMIT 20;

-- 8. Discount impact — revenue lost to discounts by month
SELECT date_trunc('month', so.order_date) AS month,
       SUM(soi.quantity * soi.unit_price * soi.discount_pct/100.0) AS discount_value
FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
WHERE so.status != 'cancelled' GROUP BY 1 ORDER BY 1;