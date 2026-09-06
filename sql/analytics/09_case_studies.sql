-- ============================================================
-- 46. High-Selling Products with Understocking Indicators
-- ============================================================
--
-- Identifies products with strong sales volume that also have
-- inventory adjustment activity, which can indicate inventory
-- control or stock availability issues.
--
-- p   = products
-- soi = sales_order_items
-- im  = inventory_movements
--
-- units_sold measures total sales quantity.
--
-- stockout_adjustments counts distinct adjustment movements for
-- the product and is used as the understocking indicator.
--
-- LEFT JOIN preserves products even when no adjustment movement
-- exists; the HAVING clause then retains only products with at
-- least one adjustment.
--
-- Result grain: one row per product.
--
-- BUSINESS NOTE:
-- An adjustment movement is only a proxy for understocking here.
-- An adjustment does not inherently mean a stockout, so this
-- metric should be interpreted as an inventory-control signal
-- rather than definitive proof of stockouts.
--
-- DESIGN NOTE:
-- The sales quantity is not restricted by sales-order status, so
-- cancelled orders can contribute to units_sold in the current
-- implementation.
-- ============================================================

SELECT p.name,
       SUM(soi.quantity) AS units_sold,

       COUNT(DISTINCT im.movement_id) FILTER (
           WHERE im.movement_type = 'adjustment'
       ) AS stockout_adjustments

FROM products p

JOIN sales_order_items soi
    ON soi.product_id = p.product_id

LEFT JOIN inventory_movements im
    ON im.product_id = p.product_id
    AND im.movement_type = 'adjustment'

GROUP BY p.name

HAVING COUNT(DISTINCT im.movement_id) > 0

ORDER BY units_sold DESC
LIMIT 20;


-- ============================================================
-- 47. High-Capacity Warehouses with Low Employee Productivity
-- ============================================================
--
-- Identifies warehouses that simultaneously satisfy two
-- operational conditions:
--
--     1. Inventory utilization is above 90%.
--     2. Orders per employee are below the overall warehouse
--        average.
--
-- w    = warehouses
-- util = warehouse utilization derived table
-- prod = warehouse productivity derived table
--
-- The utilization subquery calculates:
--     units on hand / warehouse capacity × 100
--
-- The productivity subquery calculates:
--     total orders / distinct employees
--
-- The final comparison uses the average productivity across all
-- warehouses represented in the sales_orders data.
--
-- Result grain: one row per warehouse meeting both conditions.
--
-- BUSINESS USE:
-- Highlights warehouses where capacity pressure and relatively
-- low order-processing productivity occur together, making them
-- candidates for operational investigation.
--
-- DESIGN NOTE:
-- The productivity metric is based on order volume per employee.
-- It does not account for order complexity, employee roles, working
-- hours, or differences in warehouse workload.
-- ============================================================

SELECT w.name,
       util.utilization_pct,
       prod.orders_per_employee

FROM warehouses w

JOIN (
    SELECT warehouse_id,
           100.0 * SUM(quantity_on_hand) / capacity_units AS utilization_pct

    FROM inventory i

    JOIN warehouses w2
        ON w2.warehouse_id = i.warehouse_id

    GROUP BY warehouse_id, capacity_units

) util
    ON util.warehouse_id = w.warehouse_id

JOIN (
    SELECT so.warehouse_id,
           COUNT(*)::numeric / COUNT(DISTINCT so.employee_id) AS orders_per_employee

    FROM sales_orders so

    GROUP BY so.warehouse_id

) prod
    ON prod.warehouse_id = w.warehouse_id

WHERE util.utilization_pct > 90

  AND prod.orders_per_employee < (
      SELECT AVG(orders_per_employee)

      FROM (
          SELECT warehouse_id,
                 COUNT(*)::numeric / COUNT(DISTINCT employee_id) AS orders_per_employee

          FROM sales_orders

          GROUP BY warehouse_id
      ) x
  );


-- ============================================================
-- 48. Supplier Ranking Within Country
-- ============================================================
--
-- Ranks suppliers relative to other suppliers in the same
-- country based on supplier rating.
--
-- PARTITION BY country resets the ranking independently for each
-- country.
--
-- RANK() preserves ties, so suppliers with the same rating receive
-- the same position and subsequent ranks may contain gaps.
--
-- Result grain: one row per supplier.
--
-- BUSINESS USE:
-- Enables country-level supplier benchmarking rather than comparing
-- every supplier against a global ranking.
-- ============================================================

SELECT name,
       country,
       rating,

       RANK() OVER (
           PARTITION BY country
           ORDER BY rating DESC
       ) AS rank_in_country

FROM suppliers;


-- ============================================================
-- 49. Products Never Purchased by Wholesale Customers
-- ============================================================
--
-- Identifies products that have never appeared in an order placed
-- by a wholesale customer.
--
-- p   = products
-- soi = sales_order_items
-- so  = sales_orders
-- c   = customers
--
-- The subquery builds the set of products purchased by customers
-- in the wholesale segment.
--
-- NOT IN then excludes those products from the complete product
-- set.
--
-- Result grain: one row per qualifying product.
--
-- BUSINESS USE:
-- Can identify products with no wholesale penetration and provide
-- a starting point for segment-specific sales analysis.
--
-- DESIGN NOTE:
-- NOT IN can behave unexpectedly if the subquery can return NULL.
-- Here product_id is NOT NULL in sales_order_items, so that
-- particular NULL issue is not present. NOT EXISTS is generally
-- the more defensive anti-join pattern.
-- ============================================================

SELECT DISTINCT p.name

FROM products p

WHERE p.product_id NOT IN (

    SELECT soi.product_id

    FROM sales_order_items soi

    JOIN sales_orders so
        ON so.so_id = soi.so_id

    JOIN customers c
        ON c.customer_id = so.customer_id

    WHERE c.segment = 'wholesale'

)

LIMIT 50;


-- ============================================================
-- 50. Self-Join — Same Job Title Across Warehouses
-- ============================================================
--
-- Finds pairs of employees holding the same job title while
-- working in different warehouses.
--
-- e1 and e2 are two aliases of the employees table representing
-- the two employees being compared.
--
-- The condition:
--     e1.employee_id < e2.employee_id
--
-- ensures each employee pair is returned only once and prevents
-- an employee from being paired with themselves.
--
-- warehouse_id != warehouse_id ensures the two employees belong
-- to different warehouses.
--
-- Result grain: one row per qualifying employee pair.
--
-- BUSINESS USE:
-- Useful for comparing organizational structure across warehouses
-- and identifying where the same roles are distributed geographically.
-- ============================================================

SELECT e1.first_name || ' ' || e1.last_name AS employee_a,
       e2.first_name || ' ' || e2.last_name AS employee_b,
       e1.job_title

FROM employees e1

JOIN employees e2
    ON e1.job_title = e2.job_title
    AND e1.warehouse_id != e2.warehouse_id
    AND e1.employee_id < e2.employee_id

LIMIT 50;