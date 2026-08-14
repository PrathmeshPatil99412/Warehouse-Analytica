-- 31. ROW_NUMBER — latest order per customer
SELECT * FROM (
    SELECT so.*, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM sales_orders so
) t WHERE rn = 1
LIMIT 50;

-- 32. NTILE — split products into 4 revenue quartiles
SELECT product_id, revenue, NTILE(4) OVER (ORDER BY revenue DESC) AS revenue_quartile
FROM (
    SELECT p.product_id, SUM(soi.quantity * soi.unit_price) AS revenue
    FROM products p JOIN sales_order_items soi ON soi.product_id = p.product_id
    GROUP BY p.product_id
) t
LIMIT 50;

-- 33. LAG/LEAD — order-to-order gap per customer (days between purchases)
SELECT customer_id, order_date,
       order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS days_since_prev_order
FROM sales_orders WHERE status != 'cancelled'
LIMIT 50;

-- 34. FIRST_VALUE / LAST_VALUE — each product's first and most recent sale price
SELECT DISTINCT product_id,
       FIRST_VALUE(unit_price) OVER (PARTITION BY product_id ORDER BY so_item_id) AS first_price,
       LAST_VALUE(unit_price) OVER (PARTITION BY product_id ORDER BY so_item_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_price
FROM sales_order_items
LIMIT 50;

-- 35. Moving average — 7-day rolling revenue
SELECT day, revenue, ROUND(AVG(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS rolling_7day_avg
FROM (
    SELECT so.order_date AS day, SUM(soi.quantity * soi.unit_price) AS revenue
    FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
    WHERE so.status != 'cancelled' GROUP BY so.order_date
) t ORDER BY day
LIMIT 60;

-- 36. PERCENT_RANK — employee performance percentile
SELECT employee_id, orders_handled, ROUND(PERCENT_RANK() OVER (ORDER BY orders_handled)::numeric, 3) AS percentile
FROM (
    SELECT employee_id, COUNT(*) AS orders_handled FROM sales_orders GROUP BY employee_id
) t;

-- 37. CUME_DIST — cumulative distribution of order values
SELECT so_id, order_total, ROUND(CUME_DIST() OVER (ORDER BY order_total)::numeric, 3) AS cume_dist
FROM (
    SELECT so.so_id, SUM(soi.quantity * soi.unit_price) AS order_total
    FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id GROUP BY so.so_id
) t
LIMIT 50;