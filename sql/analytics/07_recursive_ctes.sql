-- ============================================================
-- 38. Employee Management Hierarchy — Organization Chart Depth
-- ============================================================
--
-- Traverses the self-referencing employee hierarchy from top-level
-- employees down through their reporting structure.
--
-- employees.manager_id references employees.employee_id, allowing
-- the hierarchy to be represented within a single table.
--
-- Anchor rows:
--     Employees with no manager (manager_id IS NULL) form the
--     top level of the organization.
--
-- Recursive rows:
--     Each employee is attached to the employee they report to,
--     with depth incremented by one level.
--
-- Result grain: one row per employee in the reachable hierarchy.
--
-- BUSINESS USE:
-- Useful for generating organizational charts and analyzing
-- management depth.
-- ============================================================

WITH RECURSIVE org_chart AS (

    SELECT employee_id,
           manager_id,
           first_name || ' ' || last_name AS name,
           1 AS depth

    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    SELECT e.employee_id,
           e.manager_id,
           e.first_name || ' ' || e.last_name,
           oc.depth + 1

    FROM employees e
    JOIN org_chart oc
        ON e.manager_id = oc.employee_id

)

SELECT *
FROM org_chart
ORDER BY depth, name;


-- ============================================================
-- 39. Category Tree Flattened with Full Path
-- ============================================================
--
-- Traverses the recursive product-category hierarchy and converts
-- each category's position in the tree into a readable path.
--
-- parent_category_id references category_id within the same table,
-- allowing categories to contain subcategories.
--
-- Anchor rows:
--     Top-level categories with no parent.
--
-- Recursive rows:
--     Each child category is appended to its parent's path.
--
-- Example path:
--     Electronics > Computers > Laptops
--
-- Result grain: one row per reachable category.
--
-- BUSINESS USE:
-- The flattened path is useful for reporting, filtering, and
-- displaying hierarchical categories without requiring recursive
-- traversal at query time.
-- ============================================================

WITH RECURSIVE category_tree AS (

    SELECT category_id,
           name,
           parent_category_id,
           name AS full_path,
           1 AS depth

    FROM product_categories
    WHERE parent_category_id IS NULL

    UNION ALL

    SELECT c.category_id,
           c.name,
           c.parent_category_id,
           ct.full_path || ' > ' || c.name,
           ct.depth + 1

    FROM product_categories c
    JOIN category_tree ct
        ON c.parent_category_id = ct.category_id

)

SELECT *
FROM category_tree
ORDER BY full_path;


-- ============================================================
-- 40. Generated Date Dimension — Recursive CTE
-- ============================================================
--
-- Generates a calendar date series dynamically rather than relying
-- on a permanently stored date-dimension table.
--
-- The recursive CTE starts at 2023-01-01 and generates one
-- successive date until 2026-12-31.
--
-- Derived calendar attributes include:
--     day_of_week
--     month
--     quarter
--     year
--     weekend indicator
--
-- EXTRACT(DOW) follows PostgreSQL's convention:
--     0 = Sunday
--     6 = Saturday
--
-- Result grain: one row per generated calendar date.
--
-- BUSINESS USE:
-- A date dimension is useful for time-series analysis, especially
-- when joining against fact data that may have missing activity
-- dates.
--
-- DESIGN NOTE:
-- The LIMIT only restricts the displayed result; the recursive
-- definition itself still represents the full configured date range.
-- ============================================================

WITH RECURSIVE date_dim AS (

    SELECT DATE '2023-01-01' AS date

    UNION ALL

    SELECT date + 1
    FROM date_dim
    WHERE date < DATE '2026-12-31'

)

SELECT date,
       EXTRACT(dow FROM date) AS day_of_week,
       EXTRACT(month FROM date) AS month,
       EXTRACT(quarter FROM date) AS quarter,
       EXTRACT(year FROM date) AS year,
       EXTRACT(dow FROM date) IN (0,6) AS is_weekend

FROM date_dim

LIMIT 30;


-- ============================================================
-- 41. Movement Chain — Trace Product Movement Sequence
-- ============================================================
--
-- Recursively follows inventory movements for the same
-- product/warehouse combination in chronological order.
--
-- The anchor starts from inbound movements. Each recursive step
-- finds a later movement for the same product at the same
-- warehouse.
--
-- mc = movement_chain
-- im = next inventory movement
--
-- step tracks the depth of the traversal and is capped at 5 to
-- prevent an unbounded recursive expansion.
--
-- Result grain: one row per movement reached by the recursive
-- traversal.
--
-- BUSINESS USE:
-- Demonstrates recursive traversal over event/history data and
-- can be used to inspect short movement sequences for a product.
--
-- DESIGN NOTE:
-- This traces chronological movement sequences rather than a
-- true inventory lineage. Because every later movement can match
-- the previous row, the recursion can branch into multiple paths.
-- It should therefore not be described as uniquely reconstructing
-- the physical journey of a specific unit of inventory.
-- ============================================================

WITH RECURSIVE movement_chain AS (

    SELECT movement_id,
           product_id,
           warehouse_id,
           movement_type,
           quantity,
           movement_date,
           1 AS step

    FROM inventory_movements

    WHERE movement_type = 'inbound'

    UNION ALL

    SELECT im.movement_id,
           im.product_id,
           im.warehouse_id,
           im.movement_type,
           im.quantity,
           im.movement_date,
           mc.step + 1

    FROM inventory_movements im

    JOIN movement_chain mc
        ON im.product_id = mc.product_id
        AND im.warehouse_id = mc.warehouse_id
        AND im.movement_date > mc.movement_date
        AND mc.step < 5

)

SELECT *
FROM movement_chain
ORDER BY product_id, warehouse_id, movement_date
LIMIT 100;