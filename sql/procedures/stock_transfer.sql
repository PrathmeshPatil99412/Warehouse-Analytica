-- ============================================================
-- PROCEDURE: TRANSFER STOCK BETWEEN WAREHOUSES
-- ============================================================
--
-- Performs a warehouse-to-warehouse stock transfer as a single
-- logical operation.
--
-- Workflow:
--     1. Lock the source inventory row
--     2. Validate available stock
--     3. Deduct stock from the source warehouse
--     4. Add stock to the destination warehouse
--     5. Record the transfer transaction
--     6. Record both movement events for audit/history
--
-- DESIGN DECISION:
-- The source inventory row is locked before checking availability
-- so concurrent transfers cannot both read the same stock quantity
-- and oversell it.
--
-- The operation is designed so that a failure in any later step
-- causes the database transaction to roll back, preventing a
-- partially completed transfer.
-- ============================================================

-- Procedure: Transfer Stock between warehouses (atomic — both legs or neither)
CREATE OR REPLACE PROCEDURE sp_transfer_stock(
    p_product_id INTEGER, p_from_warehouse INTEGER, p_to_warehouse INTEGER,
    p_quantity INTEGER, p_employee_id INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_available INTEGER;
    v_transfer_id INTEGER;
BEGIN

    -- Lock the source inventory row before reading available stock.
    -- This serializes concurrent transfers involving the same
    -- product/warehouse combination.
    SELECT quantity_on_hand - quantity_reserved INTO v_available
    FROM inventory WHERE product_id = p_product_id AND warehouse_id = p_from_warehouse
    FOR UPDATE;

    -- Reject the transfer when the source row does not exist or
    -- available stock is insufficient.
    IF v_available IS NULL OR v_available < p_quantity THEN
        RAISE EXCEPTION 'Insufficient available stock: have %, need %', COALESCE(v_available,0), p_quantity;
    END IF;

    -- Deduct the transferred quantity from the source warehouse.
    UPDATE inventory SET quantity_on_hand = quantity_on_hand - p_quantity, last_updated = now()
    WHERE product_id = p_product_id AND warehouse_id = p_from_warehouse;

    -- Add the quantity to the destination warehouse.
    -- Create the inventory row if this product has never been stored
    -- there; otherwise increment the existing quantity.
    INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand)
    VALUES (p_product_id, p_to_warehouse, p_quantity)
    ON CONFLICT (product_id, warehouse_id)
    DO UPDATE SET quantity_on_hand = inventory.quantity_on_hand + EXCLUDED.quantity_on_hand, last_updated = now();

    -- Persist the business-level transfer transaction and capture
    -- its generated ID for movement-history traceability.
    INSERT INTO stock_transfers (product_id, from_warehouse_id, to_warehouse_id, employee_id, quantity, transfer_date, status)
    VALUES (p_product_id, p_from_warehouse, p_to_warehouse, p_employee_id, p_quantity, CURRENT_DATE, 'completed')
    RETURNING transfer_id INTO v_transfer_id;

    -- Record both sides of the physical movement:
    --     • negative quantity at the source
    --     • positive quantity at the destination
    --
    -- Both events reference the same transfer_id, allowing the
    -- movement history to be traced back to the business transaction.
    INSERT INTO inventory_movements (product_id, warehouse_id, movement_type, quantity, reference_id, reference_type)
    VALUES (p_product_id, p_from_warehouse, 'transfer_out', -p_quantity, v_transfer_id, 'transfer'),
           (p_product_id, p_to_warehouse, 'transfer_in', p_quantity, v_transfer_id, 'transfer');

END;
$$;