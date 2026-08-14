CREATE VIEW v_warehouse_utilization AS
SELECT w.warehouse_id, w.name, w.capacity_units,
       COALESCE(SUM(i.quantity_on_hand), 0) AS units_stored,
       ROUND(100.0 * COALESCE(SUM(i.quantity_on_hand), 0) / w.capacity_units, 1) AS utilization_pct
FROM warehouses w
LEFT JOIN inventory i ON i.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_id, w.name, w.capacity_units;

CREATE VIEW v_employee_productivity AS
SELECT e.employee_id, e.first_name || ' ' || e.last_name AS employee_name,
       e.warehouse_id, COUNT(so.so_id) AS orders_handled
FROM employees e
LEFT JOIN sales_orders so ON so.employee_id = e.employee_id AND so.status != 'cancelled'
GROUP BY e.employee_id, employee_name, e.warehouse_id;