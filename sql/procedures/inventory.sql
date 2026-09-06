-- ============================================================
-- PROCEDURE: RECEIVE INVENTORY
-- ============================================================
--
-- Handles the complete inventory-receiving workflow when a
-- purchase-order item is delivered.
--
-- Workflow:
--     1. Identify the product and destination warehouse
--     2. Update quantity received on the PO item
--     3. Increase current inventory
--     4. Record the inbound movement in the audit/history table
--
-- DESIGN DECISION:
-- Encapsulating these related updates in one database procedure
-- keeps the inventory state and movement history synchronized
-- instead of requiring the application to coordinate multiple
-- independent SQL statements.
-- ============================================================

-- Procedure: Receive Inventory (PO delivery arrives, stock goes up, movement logged)
CREATE OR REPLACE PROCEDURE sp_receive_inventory(
    p_po_item_id INTEGER, p_quantity_received INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_product_id INTEGER;
    v_warehouse_id INTEGER;
BEGIN

    -- Resolve the product and warehouse from the PO line item.
    -- The warehouse comes from the purchase-order header.
    SELECT poi.product_id, po.warehouse_id INTO v_product_id, v_warehouse_id
    FROM purchase_order_items poi JOIN purchase_orders po ON po.po_id = poi.po_id
    WHERE poi.po_item_id = p_po_item_id;

    -- Record the newly received quantity against the PO line.
    UPDATE purchase_order_items
    SET quantity_received = quantity_received + p_quantity_received
    WHERE po_item_id = p_po_item_id;

    -- Upsert the current inventory state:
    --     • create an inventory row if this product/warehouse pair
    --       does not exist
    --     • otherwise increment the existing stock quantity
    --
    -- The UNIQUE(product_id, warehouse_id) constraint on inventory
    -- provides the conflict target.
    INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand)
    VALUES (v_product_id, v_warehouse_id, p_quantity_received)
    ON CONFLICT (product_id, warehouse_id)
    DO UPDATE SET quantity_on_hand = inventory.quantity_on_hand + EXCLUDED.quantity_on_hand,
                  last_updated = now();

    -- Append the inbound event to the movement history.
    -- reference_id/reference_type provide traceability back to the
    -- originating purchase-order line item.
    INSERT INTO inventory_movements (product_id, warehouse_id, movement_type, quantity, reference_id, reference_type)
    VALUES (v_product_id, v_warehouse_id, 'inbound', p_quantity_received, p_po_item_id, 'purchase_order');

END;
$$;