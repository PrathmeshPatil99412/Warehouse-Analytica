-- Procedure: Receive Inventory (PO delivery arrives, stock goes up, movement logged)
CREATE OR REPLACE PROCEDURE sp_receive_inventory(
    p_po_item_id INTEGER, p_quantity_received INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_product_id INTEGER;
    v_warehouse_id INTEGER;
BEGIN
    SELECT poi.product_id, po.warehouse_id INTO v_product_id, v_warehouse_id
    FROM purchase_order_items poi JOIN purchase_orders po ON po.po_id = poi.po_id
    WHERE poi.po_item_id = p_po_item_id;

    UPDATE purchase_order_items
    SET quantity_received = quantity_received + p_quantity_received
    WHERE po_item_id = p_po_item_id;

    INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand)
    VALUES (v_product_id, v_warehouse_id, p_quantity_received)
    ON CONFLICT (product_id, warehouse_id)
    DO UPDATE SET quantity_on_hand = inventory.quantity_on_hand + EXCLUDED.quantity_on_hand,
                  last_updated = now();

    INSERT INTO inventory_movements (product_id, warehouse_id, movement_type, quantity, reference_id, reference_type)
    VALUES (v_product_id, v_warehouse_id, 'inbound', p_quantity_received, p_po_item_id, 'purchase_order');
END;
$$;