-- 9. Current stock levels by warehouse
SELECT w.name AS warehouse, SUM(i.quantity_on_hand) AS total_units
FROM inventory i JOIN warehouses w ON w.warehouse_id = i.warehouse_id
GROUP BY w.name ORDER BY total_units DESC;

-- 10. Dead stock — no outbound movement in 90+ days but stock on hand
SELECT p.name, i.warehouse_id, i.quantity_on_hand
FROM inventory i
JOIN products p ON p.product_id = i.product_id
WHERE i.quantity_on_hand > 0
  AND NOT EXISTS (
      SELECT 1 FROM inventory_movements im
      WHERE im.product_id = i.product_id AND im.warehouse_id = i.warehouse_id
        AND im.movement_type = 'outbound' AND im.movement_date > now() - interval '90 days'
  )
LIMIT 50;

-- 11. Fast movers — top 20 products by outbound velocity (last 30 days)
SELECT p.name, SUM(-im.quantity) AS units_moved
FROM inventory_movements im JOIN products p ON p.product_id = im.product_id
WHERE im.movement_type = 'outbound' AND im.movement_date > now() - interval '30 days'
GROUP BY p.name ORDER BY units_moved DESC LIMIT 20;

-- 12. Slow movers — bottom 20 active products by velocity (last 90 days)
SELECT p.name, COALESCE(SUM(-im.quantity), 0) AS units_moved
FROM products p
LEFT JOIN inventory_movements im ON im.product_id = p.product_id
    AND im.movement_type = 'outbound' AND im.movement_date > now() - interval '90 days'
GROUP BY p.name ORDER BY units_moved ASC LIMIT 20;

-- 13. Inventory aging — days since last inbound movement per product/warehouse
SELECT i.product_id, i.warehouse_id, i.quantity_on_hand,
       now()::date - MAX(im.movement_date)::date AS days_since_last_inbound
FROM inventory i
LEFT JOIN inventory_movements im ON im.product_id = i.product_id
    AND im.warehouse_id = i.warehouse_id AND im.movement_type = 'inbound'
GROUP BY i.product_id, i.warehouse_id, i.quantity_on_hand
ORDER BY days_since_last_inbound DESC NULLS FIRST
LIMIT 50;

-- 14. Products below reorder level
SELECT p.name, i.warehouse_id, i.quantity_on_hand, p.reorder_level
FROM inventory i JOIN products p ON p.product_id = i.product_id
WHERE i.quantity_on_hand < p.reorder_level
LIMIT 50;

-- 15. Inventory value by warehouse (at cost)
SELECT w.name, SUM(i.quantity_on_hand * p.unit_cost) AS inventory_value
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN warehouses w ON w.warehouse_id = i.warehouse_id
GROUP BY w.name ORDER BY inventory_value DESC;

-- 16. Stockout risk — products with < 7 days of cover at current velocity
WITH velocity AS (
    SELECT product_id, warehouse_id, SUM(-quantity) / 30.0 AS daily_avg_out
    FROM inventory_movements
    WHERE movement_type = 'outbound' AND movement_date > now() - interval '30 days'
    GROUP BY product_id, warehouse_id
)
SELECT i.product_id, i.warehouse_id, i.quantity_on_hand, v.daily_avg_out,
       ROUND(i.quantity_on_hand / NULLIF(v.daily_avg_out, 0), 1) AS days_of_cover
FROM inventory i JOIN velocity v ON v.product_id = i.product_id AND v.warehouse_id = i.warehouse_id
WHERE i.quantity_on_hand / NULLIF(v.daily_avg_out, 0) < 7
ORDER BY days_of_cover ASC
LIMIT 50;