-- 46. Products that sell well but are frequently understocked (business-critical join)
SELECT p.name, SUM(soi.quantity) AS units_sold, COUNT(DISTINCT im.movement_id) FILTER (WHERE im.movement_type='adjustment') AS stockout_adjustments
FROM products p
JOIN sales_order_items soi ON soi.product_id = p.product_id
LEFT JOIN inventory_movements im ON im.product_id = p.product_id AND im.movement_type = 'adjustment'
GROUP BY p.name HAVING COUNT(DISTINCT im.movement_id) > 0 ORDER BY units_sold DESC LIMIT 20;

-- 47. Warehouses over 90% capacity AND below-average employee productivity (multi-condition business case)
SELECT w.name, util.utilization_pct, prod.orders_per_employee
FROM warehouses w
JOIN (SELECT warehouse_id, 100.0 * SUM(quantity_on_hand) / capacity_units AS utilization_pct
      FROM inventory i JOIN warehouses w2 ON w2.warehouse_id = i.warehouse_id GROUP BY warehouse_id, capacity_units) util
    ON util.warehouse_id = w.warehouse_id
JOIN (SELECT so.warehouse_id, COUNT(*)::numeric / COUNT(DISTINCT so.employee_id) AS orders_per_employee
      FROM sales_orders so GROUP BY so.warehouse_id) prod
    ON prod.warehouse_id = w.warehouse_id
WHERE util.utilization_pct > 90
  AND prod.orders_per_employee < (SELECT AVG(orders_per_employee) FROM
      (SELECT warehouse_id, COUNT(*)::numeric / COUNT(DISTINCT employee_id) AS orders_per_employee FROM sales_orders GROUP BY warehouse_id) x);

-- 48. Suppliers ranked within their country (window function PARTITION BY)
SELECT name, country, rating,
       RANK() OVER (PARTITION BY country ORDER BY rating DESC) AS rank_in_country
FROM suppliers;

-- 49. Products never purchased by wholesale customers (anti-join, interview favorite)
SELECT DISTINCT p.name
FROM products p
WHERE p.product_id NOT IN (
    SELECT soi.product_id FROM sales_order_items soi
    JOIN sales_orders so ON so.so_id = soi.so_id
    JOIN customers c ON c.customer_id = so.customer_id
    WHERE c.segment = 'wholesale'
)
LIMIT 50;

-- 50. Self-join: employees earning the same job title in different warehouses (org design check)
SELECT e1.first_name || ' ' || e1.last_name AS employee_a, e2.first_name || ' ' || e2.last_name AS employee_b, e1.job_title
FROM employees e1
JOIN employees e2 ON e1.job_title = e2.job_title AND e1.warehouse_id != e2.warehouse_id AND e1.employee_id < e2.employee_id
LIMIT 50;