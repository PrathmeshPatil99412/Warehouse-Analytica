-- Trigger: auto-reserve inventory when a sales order line is inserted
CREATE OR REPLACE FUNCTION trg_fn_reserve_inventory_on_sale()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_warehouse_id INTEGER;
BEGIN
    SELECT warehouse_id INTO v_warehouse_id FROM sales_orders WHERE so_id = NEW.so_id;

    UPDATE inventory SET quantity_reserved = quantity_reserved + NEW.quantity
    WHERE product_id = NEW.product_id AND warehouse_id = v_warehouse_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sales_order_item_reserve
AFTER INSERT ON sales_order_items
FOR EACH ROW EXECUTE FUNCTION trg_fn_reserve_inventory_on_sale();