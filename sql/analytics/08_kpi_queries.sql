-- 42. Executive KPI snapshot (single-row dashboard summary)
SELECT
    (SELECT SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0))
     FROM sales_orders so JOIN sales_order_items soi ON soi.so_id = so.so_id
     WHERE so.status != 'cancelled' AND so.order_date > now() - interval '30 days') AS revenue_30d,
    (SELECT COUNT(*) FROM sales_orders WHERE status != 'cancelled' AND order_date > now() - interval '30 days') AS orders_30d,
    (SELECT SUM(i.quantity_on_hand * p.unit_cost) FROM inventory i JOIN products p ON p.product_id = i.product_id) AS total_inventory_value,
    (SELECT COUNT(*) FROM inventory i JOIN products p ON p.product_id = i.product_id WHERE i.quantity_on_hand < p.reorder_level) AS products_below_reorder,
    (SELECT ROUND(AVG(po.actual_delivery_date - po.order_date), 1) FROM purchase_orders po WHERE po.status = 'received') AS avg_supplier_lead_time;

-- 43. Gross margin % by product
SELECT p.name, p.unit_price, p.unit_cost,
       ROUND(100.0 * (p.unit_price - p.unit_cost) / p.unit_price, 1) AS gross_margin_pct
FROM products p ORDER BY gross_margin_pct DESC LIMIT 20;

-- 44. Order fulfillment rate (delivered / total non-cancelled)
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'delivered') / COUNT(*) FILTER (WHERE status != 'cancelled'), 2) AS fulfillment_rate_pct
FROM sales_orders;

-- 45. Inventory turnover ratio (COGS / avg inventory value) — annualized
SELECT ROUND(
    (SELECT SUM(soi.quantity * p.unit_cost) FROM sales_order_items soi JOIN products p ON p.product_id = soi.product_id
     JOIN sales_orders so ON so.so_id = soi.so_id WHERE so.status != 'cancelled' AND so.order_date > now() - interval '1 year')
    / NULLIF((SELECT AVG(i.quantity_on_hand * p.unit_cost) FROM inventory i JOIN products p ON p.product_id = i.product_id), 0)
, 2) AS inventory_turnover_ratio;