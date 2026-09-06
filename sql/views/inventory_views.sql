-- ============================================================
-- VIEW: INVENTORY STATUS
-- ============================================================
--
-- Provides a reusable warehouse-level inventory status view.
--
-- Result grain:
--     One row per product per warehouse.
--
-- Exposes both raw inventory quantities and derived operational
-- indicators such as available stock and reorder requirement.
--
-- DESIGN DECISION:
-- This logic is centralized in a view so dashboards and analytical
-- queries can reuse the same definition of "available inventory"
-- and "needs reorder" without duplicating the calculation.
-- ============================================================

CREATE VIEW v_inventory_status AS

SELECT i.product_id, p.name AS product_name, i.warehouse_id, w.name AS warehouse_name,

       i.quantity_on_hand, i.quantity_reserved,

       -- Stock physically available for new orders after reservations.
       i.quantity_on_hand - i.quantity_reserved AS quantity_available,

       p.reorder_level,

       -- Product requires replenishment when current stock falls
       -- below its configured reorder threshold.
       (i.quantity_on_hand < p.reorder_level) AS needs_reorder

FROM inventory i

JOIN products p ON p.product_id = i.product_id

JOIN warehouses w ON w.warehouse_id = i.warehouse_id;


-- ============================================================
-- VIEW: DEAD STOCK
-- ============================================================
--
-- Identifies inventory that is currently held in stock but has
-- had no outbound movement during the last 90 days.
--
-- Result grain:
--     One row per product per warehouse.
--
-- DESIGN DECISION:
-- NOT EXISTS is used to exclude product/warehouse combinations
-- with any qualifying recent outbound movement.
--
-- This makes the view useful for identifying potentially stagnant
-- inventory that may be tying up warehouse capacity and capital.
--
-- BUSINESS DEFINITION:
-- "Dead stock" here is defined as positive on-hand quantity with
-- no outbound movement in the previous 90 days. It is a project
-- specific analytical definition, not a universal accounting rule.
-- ============================================================

CREATE VIEW v_dead_stock AS

SELECT i.product_id, p.name, i.warehouse_id, i.quantity_on_hand

FROM inventory i

JOIN products p ON p.product_id = i.product_id

WHERE i.quantity_on_hand > 0

  AND NOT EXISTS (

      SELECT 1 FROM inventory_movements im

      WHERE im.product_id = i.product_id AND im.warehouse_id = i.warehouse_id

        AND im.movement_type = 'outbound' AND im.movement_date > now() - interval '90 days'

  );


-- ============================================================
-- VIEW: INVENTORY VALUE BY WAREHOUSE
-- ============================================================
--
-- Calculates the current monetary value of inventory held by
-- each warehouse.
--
-- Valuation basis:
--     quantity_on_hand × current product unit_cost
--
-- Result grain:
--     One row per warehouse.
--
-- DESIGN DECISION:
-- Inventory is valued at cost rather than selling price because
-- this represents the capital currently tied up in stock.
-- ============================================================

CREATE VIEW v_inventory_value_by_warehouse AS

SELECT w.warehouse_id, w.name, SUM(i.quantity_on_hand * p.unit_cost) AS inventory_value

FROM inventory i

JOIN products p ON p.product_id = i.product_id

JOIN warehouses w ON w.warehouse_id = i.warehouse_id

GROUP BY w.warehouse_id, w.name;