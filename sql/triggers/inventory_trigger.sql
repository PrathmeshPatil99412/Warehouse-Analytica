-- Trigger: prevent inventory from going negative (defense-in-depth beyond CHECK constraint)
CREATE OR REPLACE FUNCTION trg_fn_check_inventory_nonnegative()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.quantity_on_hand < 0 THEN
        RAISE EXCEPTION 'Inventory cannot go negative for product % at warehouse %', NEW.product_id, NEW.warehouse_id;
    END IF;
    NEW.last_updated := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_inventory_nonnegative
BEFORE UPDATE ON inventory
FOR EACH ROW EXECUTE FUNCTION trg_fn_check_inventory_nonnegative();