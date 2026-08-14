-- 38. Employee management hierarchy (org chart depth)
WITH RECURSIVE org_chart AS (
    SELECT employee_id, manager_id, first_name || ' ' || last_name AS name, 1 AS depth
    FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id, e.manager_id, e.first_name || ' ' || e.last_name, oc.depth + 1
    FROM employees e JOIN org_chart oc ON e.manager_id = oc.employee_id
)
SELECT * FROM org_chart ORDER BY depth, name;

-- 39. Category tree flattened with full path
WITH RECURSIVE category_tree AS (
    SELECT category_id, name, parent_category_id, name AS full_path, 1 AS depth
    FROM product_categories WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, c.name, c.parent_category_id, ct.full_path || ' > ' || c.name, ct.depth + 1
    FROM product_categories c JOIN category_tree ct ON c.parent_category_id = ct.category_id
)
SELECT * FROM category_tree ORDER BY full_path;

-- 40. Generated date dimension (recursive CTE building dim_date on the fly)
WITH RECURSIVE date_dim AS (
    SELECT DATE '2023-01-01' AS date
    UNION ALL
    SELECT date + 1 FROM date_dim WHERE date < DATE '2026-12-31'
)
SELECT date, EXTRACT(dow FROM date) AS day_of_week, EXTRACT(month FROM date) AS month,
       EXTRACT(quarter FROM date) AS quarter, EXTRACT(year FROM date) AS year,
       EXTRACT(dow FROM date) IN (0,6) AS is_weekend
FROM date_dim
LIMIT 30;

-- 41. Movement chain — trace a product's full inbound-to-outbound movement sequence
WITH RECURSIVE movement_chain AS (
    SELECT movement_id, product_id, warehouse_id, movement_type, quantity, movement_date,
           1 AS step
    FROM inventory_movements
    WHERE movement_type = 'inbound'
    UNION ALL
    SELECT im.movement_id, im.product_id, im.warehouse_id, im.movement_type, im.quantity, im.movement_date,
           mc.step + 1
    FROM inventory_movements im
    JOIN movement_chain mc ON im.product_id = mc.product_id AND im.warehouse_id = mc.warehouse_id
        AND im.movement_date > mc.movement_date AND mc.step < 5
)
SELECT * FROM movement_chain ORDER BY product_id, warehouse_id, movement_date LIMIT 100;