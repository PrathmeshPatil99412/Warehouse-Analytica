-- Trigger: auto-update PO status to 'received' once all lines are fully received
CREATE OR REPLACE FUNCTION trg_fn_check_po_complete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_fully_received BOOLEAN;
BEGIN
    SELECT bool_and(quantity_received >= quantity_ordered) INTO v_fully_received
    FROM purchase_order_items WHERE po_id = NEW.po_id;

    IF v_fully_received THEN
        UPDATE purchase_orders SET status = 'received', actual_delivery_date = COALESCE(actual_delivery_date, CURRENT_DATE)
        WHERE po_id = NEW.po_id AND status != 'received';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_purchase_order_item_complete
AFTER UPDATE OF quantity_received ON purchase_order_items
FOR EACH ROW EXECUTE FUNCTION trg_fn_check_po_complete();

