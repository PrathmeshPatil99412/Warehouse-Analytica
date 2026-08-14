CREATE MATERIALIZED VIEW mv_supplier_metrics AS
SELECT sp.supplier_id, sp.name, sp.rating, sp.avg_lead_time_days, sp.on_time_pct, sv.total_spend
FROM v_supplier_performance sp
JOIN v_supplier_spend sv ON sv.supplier_id = sp.supplier_id
WITH DATA;
CREATE UNIQUE INDEX ON mv_supplier_metrics (supplier_id);