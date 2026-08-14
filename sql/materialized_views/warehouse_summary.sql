CREATE MATERIALIZED VIEW mv_warehouse_summary AS
SELECT wu.warehouse_id, wu.name, wu.utilization_pct, iv.inventory_value, ep.total_orders
FROM v_warehouse_utilization wu
JOIN v_inventory_value_by_warehouse iv ON iv.warehouse_id = wu.warehouse_id
JOIN (SELECT warehouse_id, SUM(orders_handled) AS total_orders FROM v_employee_productivity GROUP BY warehouse_id) ep
    ON ep.warehouse_id = wu.warehouse_id
WITH DATA;
CREATE UNIQUE INDEX ON mv_warehouse_summary (warehouse_id);