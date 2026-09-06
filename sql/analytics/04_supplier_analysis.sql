-- ============================================================
-- 21. Average Supplier Lead Time
-- ============================================================
--
-- Measures the average number of days between purchase order
-- creation and actual delivery for each supplier.
--
-- po = purchase_orders
-- s  = suppliers
--
-- Lead time:
--     actual_delivery_date - order_date
--
-- Only received purchase orders are included because lead time
-- should be measured from completed deliveries rather than
-- pending, shipped, or cancelled orders.
--
-- Result grain: one row per supplier.
--
-- Lower lead time indicates faster supplier fulfillment.
-- ============================================================

SELECT s.name, ROUND(AVG(po.actual_delivery_date - po.order_date), 1) AS avg_lead_time_days

FROM purchase_orders po
JOIN suppliers s ON s.supplier_id = po.supplier_id

WHERE po.status = 'received'

GROUP BY s.name
ORDER BY avg_lead_time_days ASC;


-- ============================================================
-- 22. Late Delivery Rate by Supplier
-- ============================================================
--
-- Measures supplier delivery reliability by calculating the
-- percentage of received orders delivered after the expected
-- delivery date.
--
-- COUNT(*) FILTER (WHERE ...):
-- PostgreSQL conditional aggregation used to count only orders
-- that satisfy the late-delivery condition.
--
-- late_pct:
--     late deliveries / total delivered orders × 100
--
-- Suppliers with fewer than 5 completed deliveries are excluded
-- to avoid ranking suppliers based on very small samples.
--
-- Result grain: one row per supplier.
--
-- BUSINESS NOTE:
-- The minimum sample-size condition makes the comparison more
-- meaningful by avoiding conclusions from suppliers with only a
-- handful of deliveries.
-- ============================================================

SELECT s.name,

       COUNT(*) FILTER (
           WHERE po.actual_delivery_date > po.expected_delivery_date
       ) AS late_count,

       COUNT(*) AS total_delivered,

       ROUND(
           100.0 * COUNT(*) FILTER (
               WHERE po.actual_delivery_date > po.expected_delivery_date
           ) / COUNT(*),
           1
       ) AS late_pct

FROM purchase_orders po
JOIN suppliers s ON s.supplier_id = po.supplier_id

WHERE po.status = 'received'

GROUP BY s.name

HAVING COUNT(*) >= 5

ORDER BY late_pct DESC;


-- ============================================================
-- 23. Supplier Ranking by Total Spend
-- ============================================================
--
-- Calculates total procurement spend for each supplier based
-- on the quantity actually received and the recorded purchase
-- unit cost.
--
-- poi = purchase_order_items
-- po  = purchase_orders
-- s   = suppliers
--
-- Spend:
--     quantity_received × unit_cost
--
-- Using quantity_received rather than quantity_ordered means the
-- metric reflects the value of inventory actually received.
--
-- Only received purchase orders contribute to supplier spend.
--
-- Result grain: one row per supplier.
--
-- LIMIT 20 returns the suppliers with the highest procurement
-- spend.
-- ============================================================

SELECT s.name,

       SUM(poi.quantity_received * poi.unit_cost) AS total_spend

FROM purchase_order_items poi

JOIN purchase_orders po
    ON po.po_id = poi.po_id
    AND po.status = 'received'

JOIN suppliers s
    ON s.supplier_id = po.supplier_id

GROUP BY s.name

ORDER BY total_spend DESC
LIMIT 20;


-- ============================================================
-- 24. Supplier Ranking with RANK() — Ties Preserved
-- ============================================================
--
-- Same supplier-spend calculation as Query 23, but instead of
-- limiting the result to the top 20 suppliers, every supplier
-- receives an explicit rank.
--
-- RANK() is used because suppliers with identical total spend
-- should receive the same rank.
--
-- Example:
--     Supplier A -> 1
--     Supplier B -> 1
--     Supplier C -> 3
--
-- The gap after tied ranks is intentional behavior of RANK().
--
-- Result grain: one row per supplier.
--
-- INTERVIEW NOTE:
-- This demonstrates the difference between returning a Top-N
-- result and assigning a ranking while retaining the complete
-- result set.
-- ============================================================

SELECT s.name,

       SUM(poi.quantity_received * poi.unit_cost) AS total_spend,

       RANK() OVER (
           ORDER BY SUM(poi.quantity_received * poi.unit_cost) DESC
       ) AS spend_rank

FROM purchase_order_items poi

JOIN purchase_orders po
    ON po.po_id = poi.po_id
    AND po.status = 'received'

JOIN suppliers s
    ON s.supplier_id = po.supplier_id

GROUP BY s.name;


-- ============================================================
-- 25. Above-Average Rated Suppliers with Poor Lead Time
-- ============================================================
--
-- Identifies suppliers that satisfy BOTH conditions:
--
-- 1. Their rating is above the overall supplier average.
-- 2. Their average completed-order lead time exceeds 14 days.
--
-- s = suppliers
-- po = purchase_orders
--
-- The first subquery calculates the overall supplier-rating
-- benchmark.
--
-- The second subquery is correlated with the outer supplier row:
--     po.supplier_id = s.supplier_id
--
-- Therefore, the lead-time calculation is performed specifically
-- for the supplier currently being evaluated.
--
-- This combines a global benchmark (average rating) with a
-- supplier-specific operational metric (lead time).
--
-- BUSINESS INTERPRETATION:
-- These suppliers have a potentially misleading profile:
-- customers/internal stakeholders may rate them well, while their
-- actual delivery speed remains relatively poor.
--
-- DESIGN NOTE:
-- Suppliers without any received purchase orders produce NULL
-- for the correlated lead-time calculation and therefore do not
-- satisfy the > 14 condition.
-- ============================================================

SELECT s.name, s.rating

FROM suppliers s

WHERE s.rating > (
    SELECT AVG(rating)
    FROM suppliers
)

  AND (
      SELECT AVG(po.actual_delivery_date - po.order_date)

      FROM purchase_orders po

      WHERE po.supplier_id = s.supplier_id
        AND po.status = 'received'

  ) > 14;