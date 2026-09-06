-- ============================================================
-- VIEW: SUPPLIER PERFORMANCE
-- ============================================================
--
-- Measures delivery performance using only completed/received
-- purchase orders.
--
-- Result grain:
--     One row per supplier with received purchase orders.
--
-- avg_lead_time_days:
--     Average number of days between PO creation and actual delivery.
--
-- on_time_pct:
--     Percentage of received POs delivered on or before the
--     expected delivery date.
--
-- DESIGN DECISION:
-- Supplier performance is based on actual completed deliveries,
-- so pending/cancelled POs are excluded from the metrics.
--
-- FILTER is used for conditional aggregation so the total number
-- of received POs remains the denominator while only on-time
-- deliveries contribute to the numerator.
-- ============================================================

CREATE VIEW v_supplier_performance AS
SELECT s.supplier_id, s.name, s.rating,
       ROUND(AVG(po.actual_delivery_date - po.order_date), 1) AS avg_lead_time_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE po.actual_delivery_date <= po.expected_delivery_date) / NULLIF(COUNT(*), 0), 1) AS on_time_pct
FROM suppliers s
JOIN purchase_orders po ON po.supplier_id = s.supplier_id AND po.status = 'received'
GROUP BY s.supplier_id, s.name, s.rating;


-- ============================================================
-- VIEW: SUPPLIER SPEND
-- ============================================================
--
-- Calculates the actual procurement spend for each supplier
-- based on quantities received rather than quantities ordered.
--
-- Result grain:
--     One row per supplier with received purchase orders.
--
-- total_spend:
--     quantity_received × unit_cost across all received PO items.
--
-- DESIGN DECISION:
-- Using quantity_received gives a more accurate measure of
-- realized procurement spend than quantity_ordered, since a PO
-- may be partially fulfilled.
--
-- The unit_cost stored on the PO item is used instead of the
-- product's current cost, preserving the transaction-time
-- procurement price.
-- ============================================================

CREATE VIEW v_supplier_spend AS
SELECT s.supplier_id, s.name, SUM(poi.quantity_received * poi.unit_cost) AS total_spend
FROM purchase_order_items poi
JOIN purchase_orders po ON po.po_id = poi.po_id AND po.status = 'received'
JOIN suppliers s ON s.supplier_id = po.supplier_id
GROUP BY s.supplier_id, s.name;