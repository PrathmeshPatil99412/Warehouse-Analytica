-- Step 1: pull existing rows out of the DEFAULT partition into a temp holding table
CREATE TABLE inventory_movements_temp AS
SELECT * FROM inventory_movements_default;

-- Step 2: empty the DEFAULT partition completely
TRUNCATE inventory_movements_default;

-- Step 3: NOW create the real monthly partitions — DEFAULT is empty, so the
-- constraint-violation check passes cleanly
DO $$
DECLARE
    d DATE := '2023-01-01';
BEGIN
    WHILE d < '2026-09-01' LOOP
        EXECUTE format(
            'CREATE TABLE inventory_movements_%s PARTITION OF inventory_movements
             FOR VALUES FROM (%L) TO (%L);',
            to_char(d, 'YYYY_MM'), d, d + interval '1 month'
        );
        d := d + interval '1 month';
    END LOOP;
END $$;

-- Step 4: catch-all future partition so new inserts never hit an error
CREATE TABLE inventory_movements_future PARTITION OF inventory_movements
    FOR VALUES FROM ('2026-09-01') TO (MAXVALUE);

-- Step 5: reload the data — Postgres now routes each row to its correct monthly
-- partition automatically based on movement_date
INSERT INTO inventory_movements
SELECT * FROM inventory_movements_temp;

-- Step 6: clean up — detach and drop both the now-empty DEFAULT and the temp table
ALTER TABLE inventory_movements DETACH PARTITION inventory_movements_default;
DROP TABLE inventory_movements_default;
DROP TABLE inventory_movements_temp;