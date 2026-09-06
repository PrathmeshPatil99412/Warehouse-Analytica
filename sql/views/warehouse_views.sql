-- ============================================================
-- VIEW: WAREHOUSE UTILIZATION
-- ============================================================
--
-- Measures how much of each warehouse's storage capacity is
-- currently occupied by inventory.
--
-- Result grain:
--     One row per warehouse.
--
-- units_stored:
--     Total quantity currently held across all products.
--
-- utilization_pct:
--     Current units stored as a percentage of warehouse capacity.
--
-- DESIGN DECISION:
-- LEFT JOIN ensures warehouses with no inventory are still
-- represented with 0 units stored rather than being omitted.
-- COALESCE converts the NULL aggregate for such warehouses to 0.
-- ============================================================

CREATE VIEW v_warehouse_utilization AS

SELECT w.warehouse_id, w.name, w.capacity_units,

       COALESCE(SUM(i.quantity_on_hand), 0) AS units_stored,

       ROUND(100.0 * COALESCE(SUM(i.quantity_on_hand), 0) / w.capacity_units, 1) AS utilization_pct

FROM warehouses w

LEFT JOIN inventory i ON i.warehouse_id = w.warehouse_id

GROUP BY w.warehouse_id, w.name, w.capacity_units;


-- ============================================================
-- VIEW: EMPLOYEE PRODUCTIVITY
-- ============================================================
--
-- Measures employee workload using the number of non-cancelled
-- sales orders handled by each employee.
--
-- Result grain:
--     One row per employee.
--
-- orders_handled:
--     Count of sales orders associated with the employee.
--
-- DESIGN DECISION:
-- LEFT JOIN ensures employees with no handled orders are still
-- included with an orders_handled value of 0.
--
-- The metric intentionally measures order volume rather than
-- revenue, making it a workload/operational productivity metric.
-- ============================================================

CREATE VIEW v_employee_productivity AS

SELECT e.employee_id, e.first_name || ' ' || e.last_name AS employee_name,

       e.warehouse_id, COUNT(so.so_id) AS orders_handled

FROM employees e

LEFT JOIN sales_orders so ON so.employee_id = e.employee_id AND so.status != 'cancelled'

GROUP BY e.employee_id, employee_name, e.warehouse_id;