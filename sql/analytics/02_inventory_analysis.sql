-- ============================================================
-- 9. Current Stock Levels by Warehouse
-- ============================================================
--
-- i = inventory
-- w = warehouses
--
-- inventory stores the current quantity of each product at
-- each warehouse. Aggregating quantity_on_hand gives the total
-- physical units currently stored at each warehouse.
--
-- Result grain: one row per warehouse.
-- ============================================================

SELECT w.name AS warehouse, SUM(i.quantity_on_hand) AS total_units

FROM inventory i JOIN warehouses w ON w.warehouse_id = i.warehouse_id

GROUP BY w.name ORDER BY total_units DESC;


-- ============================================================
-- 10. Dead Stock — No Outbound Movement in the Last 90 Days
-- ============================================================
--
-- Identifies inventory that still has stock on hand but has had
-- no outbound movement during the last 90 days.
--
-- im = inventory_movements
--
-- NOT EXISTS is used because the requirement is to find inventory
-- rows for which NO qualifying outbound movement exists.
--
-- The check is performed at product + warehouse level so that
-- movement at one warehouse does not incorrectly classify the
-- same product at another warehouse as active.
--
-- Inventory with quantity_on_hand = 0 is excluded because there
-- is no remaining stock to classify as dead stock.
--
-- BUSINESS NOTE:
-- Dead stock ties up working capital and warehouse capacity
-- without recent evidence of demand.
-- ============================================================

SELECT p.name, i.warehouse_id, i.quantity_on_hand

FROM inventory i

JOIN products p ON p.product_id = i.product_id

WHERE i.quantity_on_hand > 0

  AND NOT EXISTS (

      SELECT 1
      FROM inventory_movements im

      WHERE im.product_id = i.product_id
        AND im.warehouse_id = i.warehouse_id
        AND im.movement_type = 'outbound'
        AND im.movement_date > now() - interval '90 days'

  )

LIMIT 50;


-- ============================================================
-- 11. Fast Movers — Top 20 Products by Outbound Velocity
-- ============================================================
--
-- Measures product movement based on outbound inventory activity
-- during the last 30 days.
--
-- inventory_movements stores outbound quantities as negative
-- movement values in this project.
--
-- Therefore:
--     SUM(-im.quantity)
-- converts outbound movement into a positive units-moved metric.
--
-- im = inventory_movements
-- p  = products
--
-- Result grain: one row per product across all warehouses.
--
-- BUSINESS NOTE:
-- This measures movement volume, not revenue. A fast-moving
-- product may therefore be inexpensive but operationally
-- significant because of its high unit volume.
-- ============================================================

SELECT p.name, SUM(-im.quantity) AS units_moved

FROM inventory_movements im
JOIN products p ON p.product_id = im.product_id

WHERE im.movement_type = 'outbound'
  AND im.movement_date > now() - interval '30 days'

GROUP BY p.name
ORDER BY units_moved DESC
LIMIT 20;


-- ============================================================
-- 12. Slow Movers — Bottom 20 Active Products by Velocity
-- ============================================================
--
-- Includes products even when they have no outbound movement
-- during the last 90 days.
--
-- The LEFT JOIN preserves products without matching movement
-- records, while COALESCE converts their NULL aggregate result
-- into zero units moved.
--
-- p  = products
-- im = inventory_movements
--
-- Result grain: one row per product.
--
-- DESIGN NOTE:
-- "Slow movers" here is based purely on outbound volume during
-- the selected 90-day window. Products with zero movement are
-- therefore ranked below products with positive movement.
-- ============================================================

SELECT p.name, COALESCE(SUM(-im.quantity), 0) AS units_moved

FROM products p

LEFT JOIN inventory_movements im
    ON im.product_id = p.product_id
    AND im.movement_type = 'outbound'
    AND im.movement_date > now() - interval '90 days'

GROUP BY p.name
ORDER BY units_moved ASC
LIMIT 20;


-- ============================================================
-- 13. Inventory Aging — Days Since Last Inbound Movement
-- ============================================================
--
-- Measures how long it has been since each product/warehouse
-- combination last received an inbound inventory movement.
--
-- im = inventory_movements
-- i  = inventory
--
-- MAX(im.movement_date) identifies the most recent inbound
-- movement for that product at that warehouse.
--
-- The difference between today's date and that movement date
-- gives the inventory age in days.
--
-- LEFT JOIN is intentional:
-- inventory that has never had an inbound movement is retained
-- in the result and produces NULL for days_since_last_inbound.
--
-- NULLS FIRST places these never-received/never-recorded cases
-- at the top because they require separate investigation.
--
-- Result grain: one row per product + warehouse inventory record.
-- ============================================================

SELECT i.product_id, i.warehouse_id, i.quantity_on_hand,

       now()::date - MAX(im.movement_date)::date AS days_since_last_inbound

FROM inventory i

LEFT JOIN inventory_movements im
    ON im.product_id = i.product_id
    AND im.warehouse_id = i.warehouse_id
    AND im.movement_type = 'inbound'

GROUP BY i.product_id, i.warehouse_id, i.quantity_on_hand

ORDER BY days_since_last_inbound DESC NULLS FIRST

LIMIT 50;


-- ============================================================
-- 14. Products Below Reorder Level
-- ============================================================
--
-- Identifies product/warehouse combinations where current stock
-- has fallen below the product's configured reorder threshold.
--
-- i.quantity_on_hand = current physical stock
-- p.reorder_level    = minimum stock threshold defined for product
--
-- Result grain: one row per product/warehouse combination
-- requiring replenishment.
--
-- BUSINESS NOTE:
-- This is an operational inventory signal rather than a demand
-- forecast. The reorder_level is a predefined threshold and does
-- not itself account for future demand velocity or supplier lead
-- time.
-- ============================================================

SELECT p.name, i.warehouse_id, i.quantity_on_hand, p.reorder_level

FROM inventory i
JOIN products p ON p.product_id = i.product_id

WHERE i.quantity_on_hand < p.reorder_level

LIMIT 50;


-- ============================================================
-- 15. Inventory Value by Warehouse (At Cost)
-- ============================================================
--
-- Calculates the current inventory carrying value using product
-- unit cost rather than selling price.
--
-- Inventory value:
--     quantity_on_hand × unit_cost
--
-- i  = inventory
-- p  = products
-- w  = warehouses
--
-- unit_cost represents the acquisition/cost basis stored for
-- the product, while unit_price represents its selling price.
--
-- Result grain: one row per warehouse.
--
-- BUSINESS NOTE:
-- Using unit_cost makes this a measure of inventory held at cost,
-- which is more appropriate for analyzing capital tied up in
-- inventory than using the customer-facing selling price.
-- ============================================================

SELECT w.name, SUM(i.quantity_on_hand * p.unit_cost) AS inventory_value

FROM inventory i

JOIN products p ON p.product_id = i.product_id

JOIN warehouses w ON w.warehouse_id = i.warehouse_id

GROUP BY w.name
ORDER BY inventory_value DESC;


-- ============================================================
-- 16. Stockout Risk — Less Than 7 Days of Inventory Cover
-- ============================================================
--
-- Estimates how many days the current inventory can support
-- demand based on recent outbound velocity.
--
-- STEP 1:
-- Calculate average daily outbound volume over the last 30 days
-- for each product/warehouse combination.
--
-- velocity:
--     average daily outbound units
--
--     SUM(-quantity) / 30.0
--
-- Negative movement quantities are converted to positive units
-- moved before calculating the average.
--
-- STEP 2:
-- Compare current stock against the calculated daily velocity.
--
-- days_of_cover:
--     current stock / average daily outbound units
--
-- Example:
--     600 units available
--     100 units/day average outbound
--     = 6 days of cover
--
-- NULLIF(daily_avg_out, 0) prevents division by zero.
--
-- Only product/warehouse combinations with an observed outbound
-- velocity are included because the query uses an INNER JOIN
-- against the velocity CTE.
--
-- BUSINESS NOTE:
-- This is a simple velocity-based risk indicator, not a full
-- demand forecast. It does not account for seasonality, pending
-- purchase orders, supplier lead time, or future demand changes.
--
-- Result is ordered by the lowest days of cover first so the most
-- urgent stockout risks appear at the top.
-- ============================================================

WITH velocity AS (

    SELECT
        product_id,
        warehouse_id,

        SUM(-quantity) / 30.0 AS daily_avg_out

    FROM inventory_movements

    WHERE movement_type = 'outbound'
      AND movement_date > now() - interval '30 days'

    GROUP BY product_id, warehouse_id

)

SELECT
    i.product_id,
    i.warehouse_id,
    i.quantity_on_hand,
    v.daily_avg_out,

    ROUND(
        i.quantity_on_hand / NULLIF(v.daily_avg_out, 0),
        1
    ) AS days_of_cover

FROM inventory i

JOIN velocity v
    ON v.product_id = i.product_id
    AND v.warehouse_id = i.warehouse_id

WHERE i.quantity_on_hand / NULLIF(v.daily_avg_out, 0) < 7

ORDER BY days_of_cover ASC

LIMIT 50;