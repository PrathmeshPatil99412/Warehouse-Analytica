-- ============================================================
-- TRIGGER FUNCTION: RESERVE INVENTORY FOR SALES ORDER
-- ============================================================
--
-- Automatically reserves inventory when a sales-order line is
-- inserted, while validating that sufficient available stock exists.
--
-- DESIGN DECISION:
-- Reservation is maintained separately from quantity_on_hand so
-- physical stock can be distinguished from stock already committed
-- to customer orders.
--
-- FOR UPDATE prevents concurrent orders from reserving the same
-- available stock based on a stale inventory value.
-- ============================================================

CREATE OR REPLACE FUNCTION trg_fn_reserve_inventory_on_sale()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_warehouse_id INTEGER;
    v_available INTEGER;
BEGIN

    -- Resolve the warehouse fulfilling the sales order.
    SELECT warehouse_id
    INTO v_warehouse_id
    FROM sales_orders
    WHERE so_id = NEW.so_id;

    -- Reject invalid order quantities.
    IF NEW.quantity <= 0 THEN
        RAISE EXCEPTION 'Sales order quantity must be positive';
    END IF;

    -- Lock the inventory row while checking available stock.
    -- This prevents concurrent orders from reserving the same stock.
    SELECT quantity_on_hand - quantity_reserved
    INTO v_available
    FROM inventory
    WHERE product_id = NEW.product_id
      AND warehouse_id = v_warehouse_id
    FOR UPDATE;

    -- Reject the reservation if the inventory row is missing
    -- or available stock is insufficient.
    IF v_available IS NULL OR v_available < NEW.quantity THEN
        RAISE EXCEPTION
            'Insufficient available inventory for product % at warehouse %: available %, requested %',
            NEW.product_id,
            v_warehouse_id,
            COALESCE(v_available, 0),
            NEW.quantity;
    END IF;

    -- Reserve the ordered quantity.
    UPDATE inventory
    SET quantity_reserved = quantity_reserved + NEW.quantity
    WHERE product_id = NEW.product_id
      AND warehouse_id = v_warehouse_id;

    RETURN NEW;

END;
$$;


-- ============================================================
-- TRIGGER DEFINITION
-- ============================================================
-- Fires after a sales-order line is inserted.
-- Each inserted line independently creates its inventory reservation.
-- ============================================================

CREATE TRIGGER trg_sales_order_item_reserve
AFTER INSERT ON sales_order_items
FOR EACH ROW
EXECUTE FUNCTION trg_fn_reserve_inventory_on_sale();