-- ============================================================
-- PROCEDURE: CREATE PURCHASE ORDER
-- ============================================================
--
-- Creates a complete purchase order from a single procedure call.
--
-- Workflow:
--     1. Create the purchase-order header
--     2. Capture the generated PO ID
--     3. Iterate through the JSONB line-item payload
--     4. Insert each item against the newly created PO
--
-- DESIGN DECISION:
-- The procedure accepts the line items as JSONB so the application
-- can submit the complete order structure in one call rather than
-- issuing separate database calls for each line item.
--
-- The generated po_id is propagated to every purchase-order item,
-- preserving the header-detail relationship.
-- ============================================================

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

    -- Create the purchase-order header and capture its generated ID.
    -- The returned ID becomes the foreign key for all line items.
    INSERT INTO purchase_orders (supplier_id, warehouse_id, employee_id, order_date, expected_delivery_date, status)
    VALUES (p_supplier_id, p_warehouse_id, p_employee_id, CURRENT_DATE, CURRENT_DATE + 14, 'pending')
    RETURNING po_id INTO v_po_id;

    -- Expand the JSONB array and create one relational row per
    -- purchase-order line item.
    --
    -- JSON values are explicitly cast to the target column types
    -- before insertion.
    FOR item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        INSERT INTO purchase_order_items (po_id, product_id, quantity_ordered, unit_cost)
        VALUES (v_po_id, (item->>'product_id')::INTEGER, (item->>'quantity')::INTEGER, (item->>'unit_cost')::NUMERIC);
    END LOOP;

    -- Provide execution feedback containing the generated PO ID
    -- and number of submitted line items.
    RAISE NOTICE 'Created PO % with % line items', v_po_id, jsonb_array_length(p_items);

END;
$$;