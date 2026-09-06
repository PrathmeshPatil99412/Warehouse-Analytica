-- ============================================================
-- 42. Executive KPI Snapshot — Single-Row Dashboard Summary
-- ============================================================
--
-- Produces a single-row summary of key operational and financial
-- KPIs for an executive dashboard.
--
-- Metrics covered:
--     revenue_30d             -> revenue generated in last 30 days
--     orders_30d              -> non-cancelled orders in last 30 days
--     total_inventory_value   -> current inventory value at cost
--     products_below_reorder  -> products currently below threshold
--     avg_supplier_lead_time  -> average completed supplier lead time
--
-- Each metric is calculated independently through a scalar
-- subquery, keeping the result at a single-row dashboard grain.
--
-- BUSINESS NOTE:
-- The 30-day metrics use a rolling time window based on the current
-- timestamp, while inventory and supplier metrics represent the
-- current/latest state available in the underlying tables.
-- ============================================================

SELECT
    (SELECT SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0))
     FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
     WHERE so.status != 'cancelled' AND so.order_date > now() - interval '30 days') AS revenue_30d,

    (SELECT COUNT(*) FROM sales_orders
     WHERE status != 'cancelled'
       AND order_date > now() - interval '30 days') AS orders_30d,

    (SELECT SUM(i.quantity_on_hand * p.unit_cost)
     FROM inventory i JOIN products p ON p.product_id = i.product_id) AS total_inventory_value,

    (SELECT COUNT(*)
     FROM inventory i JOIN products p ON p.product_id = i.product_id
     WHERE i.quantity_on_hand < p.reorder_level) AS products_below_reorder,

    (SELECT ROUND(AVG(po.actual_delivery_date - po.order_date), 1)
     FROM purchase_orders po
     WHERE po.status = 'received') AS avg_supplier_lead_time;


-- ============================================================
-- 43. Gross Margin % by Product
-- ============================================================
--
-- Calculates the gross margin percentage using the difference
-- between selling price and unit cost.
--
-- Gross margin %:
--     (unit_price - unit_cost) / unit_price × 100
--
-- Result grain: one row per product.
--
-- BUSINESS NOTE:
-- This is a product-level margin based on the current values of
-- products.unit_price and products.unit_cost. It is not a realized
-- historical margin calculated from individual sales transactions.
--
-- DESIGN NOTE:
-- Products with unit_price = 0 would cause division by zero.
-- The current schema permits unit_price = 0, so NULLIF(unit_price, 0)
-- would be a defensive improvement if zero-priced products are
-- possible in the dataset.
-- ============================================================

SELECT p.name,
       p.unit_price,
       p.unit_cost,

       ROUND(
           100.0 * (p.unit_price - p.unit_cost) / p.unit_price,
           1
       ) AS gross_margin_pct

FROM products p

ORDER BY gross_margin_pct DESC
LIMIT 20;


-- ============================================================
-- 44. Order Fulfillment Rate
-- ============================================================
--
-- Measures the percentage of non-cancelled sales orders that have
-- reached the delivered status.
--
-- Fulfillment rate:
--     delivered orders / non-cancelled orders × 100
--
-- FILTER keeps the numerator and denominator conditions explicit:
--     numerator   -> status = 'delivered'
--     denominator -> status != 'cancelled'
--
-- Result grain: single KPI row.
--
-- BUSINESS NOTE:
-- This measures final order status, not partial fulfillment,
-- shipment speed, or on-time delivery performance.
-- ============================================================

SELECT ROUND(
           100.0
           * COUNT(*) FILTER (WHERE status = 'delivered')
           / COUNT(*) FILTER (WHERE status != 'cancelled'),
           2
       ) AS fulfillment_rate_pct

FROM sales_orders;


-- ============================================================
-- 45. Inventory Turnover Ratio — Annualized
-- ============================================================
--
-- Estimates inventory turnover using the last year's sales-based
-- COGS divided by the current average inventory value.
--
-- COGS proxy:
--     sold quantity × current product unit cost
--
-- Inventory value:
--     quantity_on_hand × current product unit cost
--
-- NULLIF protects the ratio when the inventory valuation is zero.
--
-- Result grain: single KPI row.
--
-- BUSINESS NOTE:
-- A higher turnover generally indicates inventory is being converted
-- into sales more frequently, while a lower turnover can indicate
-- slower-moving or excess inventory.
--
-- DESIGN NOTE:
-- Despite the "annualized" label, the numerator already covers the
-- last 12 months. The denominator is the current inventory value,
-- not an average inventory balance across the year. A more rigorous
-- turnover calculation would use average beginning/end inventory
-- or periodic inventory snapshots.
--
-- DESIGN NOTE:
-- COGS uses the current p.unit_cost for historical sales rather than
-- the transaction-time cost. This is an approximation because the
-- schema does not store historical product cost on sales transactions.
-- ============================================================

SELECT ROUND(

    (SELECT SUM(soi.quantity * p.unit_cost)
     FROM sales_order_items soi

     JOIN products p
       ON p.product_id = soi.product_id

     JOIN sales_orders so
       ON so.so_id = soi.so_id

     WHERE so.status != 'cancelled'
       AND so.order_date > now() - interval '1 year')

    /

    NULLIF(
        (SELECT AVG(i.quantity_on_hand * p.unit_cost)
         FROM inventory i
         JOIN products p
           ON p.product_id = i.product_id),
        0
    ),

    2

) AS inventory_turnover_ratio;