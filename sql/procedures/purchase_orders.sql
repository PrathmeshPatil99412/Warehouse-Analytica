-- Procedure: Create Purchase Order (header + items in one transaction)
CREATE OR REPLACE PROCEDURE sp_create_purchase_order(
    p_supplier_id INTEGER, p_warehouse_id INTEGER, p_employee_id INTEGER,
    p_items JSONB  -- [{"product_id":1,"quantity":100,"unit_cost":12.50}, ...]
)
LANGUAGE plpgsql AS $$
DECLARE
    v_po_id INTEGER;
    item JSONB;
BEGIN
    INSERT INTO purchase_orders (supplier_id, warehouse_id, employee_id, order_date, expected_delivery_date, status)
    VALUES (p_supplier_id, p_warehouse_id, p_employee_id, CURRENT_DATE, CURRENT_DATE + 14, 'pending')
    RETURNING po_id INTO v_po_id;

    FOR item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        INSERT INTO purchase_order_items (po_id, product_id, quantity_ordered, unit_cost)
        VALUES (v_po_id, (item->>'product_id')::INTEGER, (item->>'quantity')::INTEGER, (item->>'unit_cost')::NUMERIC);
    END LOOP;

    RAISE NOTICE 'Created PO % with % line items', v_po_id, jsonb_array_length(p_items);
END;
$$;