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
    SELECT quantity_on_hand - quantity_reserved INTO v_available
    FROM inventory WHERE product_id = p_product_id AND warehouse_id = p_from_warehouse
    FOR UPDATE;

    IF v_available IS NULL OR v_available < p_quantity THEN
        RAISE EXCEPTION 'Insufficient available stock: have %, need %', COALESCE(v_available,0), p_quantity;
    END IF;

    UPDATE inventory SET quantity_on_hand = quantity_on_hand - p_quantity, last_updated = now()
    WHERE product_id = p_product_id AND warehouse_id = p_from_warehouse;

    INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand)
    VALUES (p_product_id, p_to_warehouse, p_quantity)
    ON CONFLICT (product_id, warehouse_id)
    DO UPDATE SET quantity_on_hand = inventory.quantity_on_hand + EXCLUDED.quantity_on_hand, last_updated = now();

    INSERT INTO stock_transfers (product_id, from_warehouse_id, to_warehouse_id, employee_id, quantity, transfer_date, status)
    VALUES (p_product_id, p_from_warehouse, p_to_warehouse, p_employee_id, p_quantity, CURRENT_DATE, 'completed')
    RETURNING transfer_id INTO v_transfer_id;

    INSERT INTO inventory_movements (product_id, warehouse_id, movement_type, quantity, reference_id, reference_type)
    VALUES (p_product_id, p_from_warehouse, 'transfer_out', -p_quantity, v_transfer_id, 'transfer'),
           (p_product_id, p_to_warehouse, 'transfer_in', p_quantity, v_transfer_id, 'transfer');
END;
$$;