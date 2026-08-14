-- 17. Warehouse utilization % (units on hand vs capacity)
SELECT w.name, w.capacity_units, SUM(i.quantity_on_hand) AS units_stored,
       ROUND(100.0 * SUM(i.quantity_on_hand) / w.capacity_units, 1) AS utilization_pct
FROM warehouses w JOIN inventory i ON i.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_id, w.name, w.capacity_units ORDER BY utilization_pct DESC;

-- 18. Transfer volume between warehouse pairs
SELECT wf.name AS from_warehouse, wt.name AS to_warehouse, COUNT(*) AS transfer_count, SUM(st.quantity) AS units_transferred
FROM stock_transfers st
JOIN warehouses wf ON wf.warehouse_id = st.from_warehouse_id
JOIN warehouses wt ON wt.warehouse_id = st.to_warehouse_id
WHERE st.status = 'completed'
GROUP BY wf.name, wt.name ORDER BY units_transferred DESC;

-- 19. Employee productivity — orders processed per employee (sales side)
SELECT e.first_name || ' ' || e.last_name AS employee, w.name AS warehouse, COUNT(*) AS orders_handled
FROM sales_orders so
JOIN employees e ON e.employee_id = so.employee_id
JOIN warehouses w ON w.warehouse_id = so.warehouse_id
WHERE so.status != 'cancelled'
GROUP BY employee, w.name ORDER BY orders_handled DESC LIMIT 20;

-- 20. Warehouse revenue contribution %
SELECT w.name,
       SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0)) AS revenue,
       ROUND(100.0 * SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0))
             / SUM(SUM(soi.quantity * soi.unit_price * (1 - soi.discount_pct/100.0))) OVER (), 2) AS pct_of_total
FROM sales_orders so
JOIN sales_order_items soi ON soi.so_id = so.so_id
JOIN warehouses w ON w.warehouse_id = so.warehouse_id
WHERE so.status != 'cancelled'
GROUP BY w.name ORDER BY revenue DESC;