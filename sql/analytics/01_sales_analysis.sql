-- ============================================================
-- 1. Total Revenue by Month
-- ============================================================
--
-- so  = sales_orders
-- soi = sales_order_items
--
-- Revenue is calculated at line-item level after applying the
-- discount stored on each sales order item.
--
-- Cancelled orders are excluded from revenue calculations.
-- Result grain: one row per calendar month.
-- ============================================================

SELECT date_trunc('month', so.order_date) AS month,

       SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue

FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id

WHERE so.status != 'cancelled'

GROUP BY 1 ORDER BY 1;


-- ============================================================
-- 2. Month-over-Month Growth %
-- ============================================================
--
-- First aggregate revenue to monthly grain, then compare each
-- month with the immediately preceding month.
--
-- LAG(revenue) provides the previous month's revenue.
--
-- NULLIF(..., 0) prevents division by zero when the previous
-- month's revenue is zero.
--
-- The first month has no previous month, so its growth value
-- will naturally be NULL.
-- ============================================================

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


-- ============================================================
-- 3. Year-over-Year Growth %
-- ============================================================
--
-- Revenue is first aggregated at monthly grain.
--
-- LAG(revenue, 12) compares the current month with the value
-- 12 monthly rows earlier, representing the same month in the
-- previous year.
--
-- This provides a year-over-year comparison rather than a
-- consecutive-month comparison.
--
-- NULLIF(..., 0) protects the percentage calculation from
-- division by zero.
--
-- DESIGN NOTE:
-- This assumes the monthly result contains continuous monthly
-- rows. If months can be completely absent, a generated calendar
-- series would provide a stricter month-to-month alignment.
-- ============================================================

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


-- ============================================================
-- 4. Running Total Revenue (YTD)
-- ============================================================
--
-- The inner query establishes monthly revenue as the required
-- analytical grain.
--
-- t = derived table containing one row per month.
--
-- The outer window SUM maintains a separate cumulative total
-- for each calendar year.
--
-- PARTITION BY year resets the running total when a new year
-- begins.
--
-- Result:
-- January  -> January revenue
-- February -> January + February
-- March    -> January + February + March
-- etc.
-- ============================================================

SELECT month, revenue,

       SUM(revenue) OVER (PARTITION BY date_trunc('year', month) ORDER BY month) AS ytd_running_total

FROM (

    SELECT date_trunc('month', so.order_date) AS month,

           SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue

    FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id

    WHERE so.status != 'cancelled' GROUP BY 1

) t ORDER BY month;


-- ============================================================
-- 5. Revenue by Product Category
-- ============================================================
--
-- soi = sales_order_items
-- p   = products
-- pc  = product_categories
-- so  = sales_orders
--
-- Relationship path:
-- sales_order_items -> products -> product_categories
--
-- Revenue is attributed to the category of each sold product.
--
-- The sales order header is joined to exclude cancelled orders,
-- since order status is stored at the sales_orders level.
--
-- Result grain: one row per product category.
-- ============================================================

SELECT pc.name AS category, SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue

FROM sales_order_items soi

JOIN products p ON p.product_id = soi.product_id

JOIN product_categories pc ON pc.category_id = p.category_id

JOIN sales_orders so ON so.so_id = soi.so_id AND so.status != 'cancelled'

GROUP BY pc.name ORDER BY revenue DESC;


-- ============================================================
-- 6. Average Order Value by Customer Segment
-- ============================================================
--
-- AOV must be calculated from order-level totals rather than
-- directly averaging individual line-item values.
--
-- The inner query therefore establishes:
--     one row = one sales order
--
-- o = derived table containing order-level revenue.
-- c = customers
--
-- After calculating each order's total, orders are associated
-- with their customer's segment and averaged by segment.
--
-- This preserves the correct analytical grain for AOV.
-- ============================================================

SELECT c.segment, ROUND(AVG(order_total), 2) AS avg_order_value

FROM (

    SELECT so.so_id, so.customer_id,

           SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS order_total

    FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id

    WHERE so.status != 'cancelled' GROUP BY so.so_id, so.customer_id

) o JOIN customers c ON c.customer_id = o.customer_id

GROUP BY c.segment ORDER BY avg_order_value DESC;


-- ============================================================
-- 7. Best-Selling Products by Quantity
-- ============================================================
--
-- soi = sales_order_items
-- p   = products
-- so  = sales_orders
--
-- Measures product performance by total units sold rather than
-- revenue. This can identify high-volume products independently
-- of their selling price.
--
-- Cancelled orders are excluded.
--
-- Result grain: one row per product.
-- LIMIT 20 returns the top 20 products after ranking by units sold.
-- ============================================================

SELECT p.name, SUM(soi.quantity) AS units_sold

FROM sales_order_items soi JOIN products p ON p.product_id = soi.product_id

JOIN sales_orders so ON so.so_id = soi.so_id AND so.status != 'cancelled'

GROUP BY p.name ORDER BY units_sold DESC LIMIT 20;


-- ============================================================
-- 8. Discount Impact — Discount Value by Month
-- ============================================================
--
-- Calculates the monetary value of discounts granted on
-- non-cancelled sales orders for each month.
--
-- Discount value:
--     quantity × unit_price × discount%
--
-- This represents the value given up through discounts against
-- the undiscounted selling price.
--
-- BUSINESS NOTE:
-- "Discount value" is more precise than treating the entire
-- amount as accounting revenue loss, since the discount may have
-- been intentionally used to generate the sale.
--
-- Result grain: one row per calendar month.
-- ============================================================

SELECT date_trunc('month', so.order_date) AS month,

       SUM(soi.quantity * soi.unit_price * soi.discount_pct/100.0) AS discount_value

FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id

WHERE so.status != 'cancelled' GROUP BY 1 ORDER BY 1;