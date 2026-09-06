-- ============================================================
-- TRIGGER FUNCTION: AUTO-COMPLETE PURCHASE ORDER
-- ============================================================
--
-- Automatically marks a purchase order as 'received' once every
-- associated line item has been fully received.
--
-- DESIGN DECISION:
-- The PO status is derived from its line-item state. Keeping this
-- rule in the database prevents application code from having to
-- remember to update the PO header after every receiving operation.
--
-- bool_and() evaluates the condition across all line items:
--     TRUE  -> every line is fully received
--     FALSE -> at least one line is still outstanding
-- ============================================================

-- Trigger: auto-update PO status to 'received' once all lines are fully received
CREATE OR REPLACE FUNCTION trg_fn_check_po_complete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_fully_received BOOLEAN;
BEGIN

    -- Check whether every line item belonging to this PO has been
    -- received in full.
    SELECT bool_and(quantity_received >= quantity_ordered) INTO v_fully_received
    FROM purchase_order_items WHERE po_id = NEW.po_id;

    -- Once all lines are complete, update the PO header.
    -- Preserve an existing actual_delivery_date if one is already set.
    IF v_fully_received THEN
        UPDATE purchase_orders SET status = 'received', actual_delivery_date = COALESCE(actual_delivery_date, CURRENT_DATE)
        WHERE po_id = NEW.po_id AND status != 'received';
    END IF;

    RETURN NEW;

END;
$$;


-- ============================================================
-- TRIGGER DEFINITION
-- ============================================================
--
-- Fires after quantity_received changes on a PO line item.
--
-- AFTER UPDATE is appropriate because the function evaluates the
-- resulting state of the purchase-order items after the update
-- has been applied.
-- ============================================================

CREATE TRIGGER trg_purchase_order_item_complete
AFTER UPDATE OF quantity_received ON purchase_order_items

FOR EACH ROW EXECUTE FUNCTION trg_fn_check_po_complete();