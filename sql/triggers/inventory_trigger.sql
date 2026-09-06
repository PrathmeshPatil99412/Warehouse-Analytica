-- ============================================================
-- TRIGGER FUNCTION: INVENTORY VALIDATION
-- ============================================================
--
-- Provides an additional database-level safeguard against
-- negative inventory and automatically maintains the
-- last_updated timestamp whenever inventory is modified.
--
-- DESIGN DECISION:
-- The table already has a CHECK constraint enforcing
-- quantity_on_hand >= 0. The trigger therefore acts as
-- defense-in-depth while also handling timestamp maintenance.
--
-- Keeping this logic at the database layer ensures it applies
-- regardless of which application path performs the update.
-- ============================================================

-- Trigger: prevent inventory from going negative (defense-in-depth beyond CHECK constraint)

CREATE OR REPLACE FUNCTION trg_fn_check_inventory_nonnegative()

RETURNS TRIGGER LANGUAGE plpgsql AS $$

BEGIN

    -- Reject any update that would result in negative stock.
    IF NEW.quantity_on_hand < 0 THEN

        RAISE EXCEPTION 'Inventory cannot go negative for product % at warehouse %', NEW.product_id, NEW.warehouse_id;

    END IF;

    -- Automatically update the modification timestamp rather than
    -- relying on every application update path to maintain it.
    NEW.last_updated := now();

    RETURN NEW;

END;

$$;


-- ============================================================
-- TRIGGER DEFINITION
-- ============================================================
--
-- Fires before every inventory UPDATE, allowing the new row to be
-- validated and modified before PostgreSQL writes it.
--
-- FOR EACH ROW means the function executes independently for every
-- inventory row affected by an UPDATE statement.
-- ============================================================

CREATE TRIGGER trg_inventory_nonnegative

BEFORE UPDATE ON inventory

FOR EACH ROW EXECUTE FUNCTION trg_fn_check_inventory_nonnegative();