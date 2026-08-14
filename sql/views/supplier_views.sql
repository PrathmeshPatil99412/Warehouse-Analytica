CREATE VIEW v_supplier_performance AS
SELECT s.supplier_id, s.name, s.rating,
       ROUND(AVG(po.actual_delivery_date - po.order_date), 1) AS avg_lead_time_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE po.actual_delivery_date <= po.expected_delivery_date) / NULLIF(COUNT(*), 0), 1) AS on_time_pct
FROM suppliers s
JOIN purchase_orders po ON po.supplier_id = s.supplier_id AND po.status = 'received'
GROUP BY s.supplier_id, s.name, s.rating;

CREATE VIEW v_supplier_spend AS
SELECT s.supplier_id, s.name, SUM(poi.quantity_received * poi.unit_cost) AS total_spend
FROM purchase_order_items poi
JOIN purchase_orders po ON po.po_id = poi.po_id AND po.status = 'received'
JOIN suppliers s ON s.supplier_id = po.supplier_id
GROUP BY s.supplier_id, s.name;