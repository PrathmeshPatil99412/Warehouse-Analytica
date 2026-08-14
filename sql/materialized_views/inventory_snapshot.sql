CREATE MATERIALIZED VIEW mv_inventory_snapshot AS
SELECT product_id, warehouse_id, quantity_on_hand, quantity_available, needs_reorder
FROM v_inventory_status
WITH DATA;
CREATE UNIQUE INDEX ON mv_inventory_snapshot (product_id, warehouse_id);