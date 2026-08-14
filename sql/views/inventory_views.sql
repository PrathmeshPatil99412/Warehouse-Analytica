CREATE VIEW v_inventory_status AS
SELECT i.product_id, p.name AS product_name, i.warehouse_id, w.name AS warehouse_name,
       i.quantity_on_hand, i.quantity_reserved,
       i.quantity_on_hand - i.quantity_reserved AS quantity_available,
       p.reorder_level,
       (i.quantity_on_hand < p.reorder_level) AS needs_reorder
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN warehouses w ON w.warehouse_id = i.warehouse_id;

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

CREATE VIEW v_inventory_value_by_warehouse AS
SELECT w.warehouse_id, w.name, SUM(i.quantity_on_hand * p.unit_cost) AS inventory_value
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN warehouses w ON w.warehouse_id = i.warehouse_id
GROUP BY w.warehouse_id, w.name;