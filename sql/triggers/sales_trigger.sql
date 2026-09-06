-- ============================================================
-- TRIGGER FUNCTION: RESERVE INVENTORY FOR SALES ORDER
-- ============================================================
--
-- Automatically reserves inventory when a sales-order line is
-- created.
--
-- Workflow:
--     1. Identify the warehouse associated with the sales order
--     2. Increase reserved quantity for the ordered product
--
-- DESIGN DECISION:
-- Reservation is maintained separately from quantity_on_hand.
-- This allows the system to distinguish physically available stock
-- from stock already committed to customer orders.
--
-- The trigger keeps this reservation logic at the database layer,
-- ensuring that inserting a sales-order item automatically updates
-- the corresponding inventory state.
-- ============================================================

-- Trigger: auto-reserve inventory when a sales order line is inserted
CREATE OR REPLACE FUNCTION trg_fn_reserve_inventory_on_sale()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_warehouse_id INTEGER;
BEGIN

    -- Resolve the warehouse from the sales-order header.
    SELECT warehouse_id INTO v_warehouse_id FROM sales_orders WHERE so_id = NEW.so_id;

    -- Reserve the ordered quantity for this product at the
    -- warehouse fulfilling the sales order.
    UPDATE inventory SET quantity_reserved = quantity_reserved + NEW.quantity
    WHERE product_id = NEW.product_id AND warehouse_id = v_warehouse_id;

    RETURN NEW;

END;
$$;


-- ============================================================
-- TRIGGER DEFINITION
-- ============================================================
--
-- Fires after a sales-order line is inserted so the reservation
-- is created immediately after the order line exists.
--
-- FOR EACH ROW ensures that every newly inserted order line
-- generates its corresponding inventory reservation.
-- ============================================================

CREATE TRIGGER trg_sales_order_item_reserve
AFTER INSERT ON sales_order_items

FOR EACH ROW EXECUTE FUNCTION trg_fn_reserve_inventory_on_sale();