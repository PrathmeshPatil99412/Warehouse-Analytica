-- 21. Average supplier lead time (order to actual delivery)
SELECT s.name, ROUND(AVG(po.actual_delivery_date - po.order_date), 1) AS avg_lead_time_days
FROM purchase_orders po JOIN suppliers s ON s.supplier_id = po.supplier_id
WHERE po.status = 'received'
GROUP BY s.name ORDER BY avg_lead_time_days ASC;

-- 22. Late delivery rate by supplier
SELECT s.name,
       COUNT(*) FILTER (WHERE po.actual_delivery_date > po.expected_delivery_date) AS late_count,
       COUNT(*) AS total_delivered,
       ROUND(100.0 * COUNT(*) FILTER (WHERE po.actual_delivery_date > po.expected_delivery_date) / COUNT(*), 1) AS late_pct
FROM purchase_orders po JOIN suppliers s ON s.supplier_id = po.supplier_id
WHERE po.status = 'received'
GROUP BY s.name HAVING COUNT(*) >= 5 ORDER BY late_pct DESC;

-- 23. Supplier ranking by total spend
SELECT s.name, SUM(poi.quantity_received * poi.unit_cost) AS total_spend
FROM purchase_order_items poi
JOIN purchase_orders po ON po.po_id = poi.po_id AND po.status = 'received'
JOIN suppliers s ON s.supplier_id = po.supplier_id
GROUP BY s.name ORDER BY total_spend DESC LIMIT 20;

-- 24. Supplier ranking with RANK() window function (ties handled)
SELECT s.name, SUM(poi.quantity_received * poi.unit_cost) AS total_spend,
       RANK() OVER (ORDER BY SUM(poi.quantity_received * poi.unit_cost) DESC) AS spend_rank
FROM purchase_order_items poi
JOIN purchase_orders po ON po.po_id = poi.po_id AND po.status = 'received'
JOIN suppliers s ON s.supplier_id = po.supplier_id
GROUP BY s.name;

-- 25. Suppliers with above-average rating whose lead time is still poor (correlated subquery)
SELECT s.name, s.rating
FROM suppliers s
WHERE s.rating > (SELECT AVG(rating) FROM suppliers)
  AND (
      SELECT AVG(po.actual_delivery_date - po.order_date)
      FROM purchase_orders po WHERE po.supplier_id = s.supplier_id AND po.status = 'received'
  ) > 14;