-- ============================================================
-- 31. ROW_NUMBER — Latest Order per Customer
-- ============================================================
--
-- Assigns a descending row number to each customer's orders,
-- allowing the most recent order to be isolated with rn = 1.
--
-- The inner query establishes the ranking within each customer.
-- The outer query filters to the latest order.
--
-- Result grain: one row per customer with at least one order.
--
-- BUSINESS NOTE:
-- ORDER BY order_date DESC determines recency. If multiple orders
-- can share the same order_date, adding so_id DESC would provide
-- deterministic tie-breaking.
-- ============================================================

SELECT * FROM (

    SELECT so.*,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY order_date DESC
           ) AS rn

    FROM sales_orders so

) t

WHERE rn = 1

LIMIT 50;


-- ============================================================
-- 32. NTILE — Split Products into Revenue Quartiles
-- ============================================================
--
-- Ranks products into four approximately equal-sized groups based
-- on their total sales revenue.
--
-- Products are ordered from highest to lowest revenue, so:
--     1 -> highest-revenue quartile
--     4 -> lowest-revenue quartile
--
-- The inner query first establishes product-level revenue.
--
-- Result grain: one row per product.
--
-- BUSINESS NOTE:
-- NTILE(4) creates four ranked groups by row count; these are
-- quartiles by product population, not four equal revenue ranges.
-- ============================================================

SELECT product_id,
       revenue,
       NTILE(4) OVER (ORDER BY revenue DESC) AS revenue_quartile

FROM (

    SELECT p.product_id,
           SUM(soi.quantity * soi.unit_price) AS revenue

    FROM products p

    JOIN sales_order_items soi
        ON soi.product_id = p.product_id

    GROUP BY p.product_id

) t

LIMIT 50;


-- ============================================================
-- 33. LAG — Order-to-Order Gap per Customer
-- ============================================================
--
-- Calculates the number of days between each customer's current
-- order and their immediately preceding non-cancelled order.
--
-- The window is partitioned by customer so comparisons never
-- cross customer boundaries.
--
-- For each customer's first order, LAG() has no previous row,
-- therefore days_since_prev_order is NULL.
--
-- Result grain: one row per non-cancelled sales order.
--
-- BUSINESS USE:
-- Useful for analyzing purchase frequency and identifying changes
-- in customer ordering behavior.
-- ============================================================

SELECT customer_id,
       order_date,

       order_date - LAG(order_date) OVER (
           PARTITION BY customer_id
           ORDER BY order_date
       ) AS days_since_prev_order

FROM sales_orders

WHERE status != 'cancelled'

LIMIT 50;


-- ============================================================
-- 34. FIRST_VALUE / LAST_VALUE — Sale Price History per Product
-- ============================================================
--
-- Returns the first recorded sale price and the most recent
-- recorded sale price for each product.
--
-- Ordering by so_item_id establishes the chronological sequence
-- used by this query.
--
-- The explicit window frame for LAST_VALUE is important because
-- the default frame would otherwise end at the current row rather
-- than the final row of the product's partition.
--
-- DISTINCT collapses the window-function output to one row per
-- product.
--
-- Result grain: one row per product.
--
-- BUSINESS NOTE:
-- This reflects the first/latest recorded transaction price in
-- sales_order_items, not the current value in products.unit_price.
-- ============================================================

SELECT DISTINCT product_id,

       FIRST_VALUE(unit_price) OVER (
           PARTITION BY product_id
           ORDER BY so_item_id
       ) AS first_price,

       LAST_VALUE(unit_price) OVER (
           PARTITION BY product_id
           ORDER BY so_item_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS latest_price

FROM sales_order_items

LIMIT 50;


-- ============================================================
-- 35. Moving Average — 7-Day Rolling Revenue
-- ============================================================
--
-- Calculates a rolling average over the current revenue day and
-- the six preceding rows.
--
-- The inner query first establishes daily revenue, which is
-- necessary before applying the rolling calculation.
--
-- Result grain:
--     inner query -> one row per day
--     final query -> one row per revenue day
--
-- BUSINESS NOTE:
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW means seven observed
-- rows, not necessarily seven calendar days. If a day has no
-- orders, that date is absent and therefore does not contribute
-- a zero-revenue row to the window.
-- ============================================================

SELECT day,
       revenue,

       ROUND(
           AVG(revenue) OVER (
               ORDER BY day
               ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
           ),
           2
       ) AS rolling_7day_avg

FROM (

    SELECT so.order_date AS day,
           SUM(soi.quantity * soi.unit_price) AS revenue

    FROM sales_orders so

    JOIN sales_order_items soi
        ON soi.so_id = so.so_id

    WHERE so.status != 'cancelled'

    GROUP BY so.order_date

) t

ORDER BY day

LIMIT 60;


-- ============================================================
-- 36. PERCENT_RANK — Employee Performance Percentile
-- ============================================================
--
-- Positions employees relative to one another based on the number
-- of sales orders they have handled.
--
-- The inner query establishes the employee-level order count.
--
-- Result grain: one row per employee appearing in sales_orders.
--
-- PERCENT_RANK returns a relative position from 0 to 1:
--     0   -> lowest-ranked employee
--     1   -> highest-ranked employee
--
-- BUSINESS NOTE:
-- This measures order volume only. It does not account for revenue,
-- order complexity, processing time, or employee workload.
-- ============================================================

SELECT employee_id,
       orders_handled,

       ROUND(
           PERCENT_RANK() OVER (
               ORDER BY orders_handled
           )::numeric,
           3
       ) AS percentile

FROM (

    SELECT employee_id,
           COUNT(*) AS orders_handled

    FROM sales_orders

    GROUP BY employee_id

) t;


-- ============================================================
-- 37. CUME_DIST — Cumulative Distribution of Order Values
-- ============================================================
--
-- Measures the proportion of orders whose total value is less
-- than or equal to each order's value.
--
-- The inner query first calculates the total value of each order.
--
-- Result grain:
--     inner query -> one row per sales order
--     final query -> one row per sales order
--
-- CUME_DIST is useful for answering questions such as:
-- "What percentage of orders have a value at or below this order?"
--
-- BUSINESS NOTE:
-- The ordering is ascending, so higher-value orders have larger
-- cumulative distribution values.
-- ============================================================

SELECT so_id,
       order_total,

       ROUND(
           CUME_DIST() OVER (
               ORDER BY order_total
           )::numeric,
           3
       ) AS cume_dist

FROM (

    SELECT so.so_id,
           SUM(soi.quantity * soi.unit_price) AS order_total

    FROM sales_orders so

    JOIN sales_order_items soi
        ON soi.so_id = so.so_id

    GROUP BY so.so_id

) t

LIMIT 50;