CREATE VIEW v_order_revenue AS
SELECT so.so_id, so.customer_id, so.warehouse_id, so.employee_id, so.order_date, so.status,
       SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS order_total
FROM sales_orders so
JOIN sales_order_items soi ON soi.so_id = so.so_id
GROUP BY so.so_id, so.customer_id, so.warehouse_id, so.employee_id, so.order_date, so.status;

CREATE VIEW v_customer_ltv AS
SELECT c.customer_id, c.name, c.segment,
       SUM(orv.order_total) AS lifetime_value,
       COUNT(orv.so_id) AS order_count
FROM customers c
JOIN v_order_revenue orv ON orv.customer_id = c.customer_id AND orv.status != 'cancelled'
GROUP BY c.customer_id, c.name, c.segment;

CREATE VIEW v_daily_revenue AS
SELECT order_date, SUM(order_total) AS revenue
FROM v_order_revenue
WHERE status != 'cancelled'
GROUP BY order_date;