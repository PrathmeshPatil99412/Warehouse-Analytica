-- ============================================================
-- PARTITION MIGRATION: DEFAULT → MONTHLY RANGE PARTITIONS
-- ============================================================
--
-- The table was initially using a DEFAULT partition. This migration
-- replaces that catch-all storage with monthly range partitions.
--
-- Migration flow:
--     1. Preserve existing DEFAULT-partitioned rows
--     2. Empty DEFAULT so new partition bounds can be created
--     3. Create monthly partitions
--     4. Add a future catch-all partition
--     5. Reload historical data and let PostgreSQL route each row
--     6. Remove the obsolete DEFAULT partition and staging table
--
-- This approach avoids partition-bound conflicts while preserving
-- the existing movement history.
-- ============================================================


-- ============================================================
-- Step 1: Preserve Existing DEFAULT-Partitioned Data
-- ============================================================
--
-- Copy the rows currently stored in the DEFAULT partition into a
-- temporary holding table.
--
-- This is necessary because the DEFAULT partition must be emptied
-- before creating monthly partitions whose ranges may contain some
-- of those existing rows.
-- ============================================================

-- Step 1: pull existing rows out of the DEFAULT partition into a temp holding table

CREATE TABLE inventory_movements_temp AS

SELECT * FROM inventory_movements_default;


-- ============================================================
-- Step 2: Empty the DEFAULT Partition
-- ============================================================
--
-- TRUNCATE removes the rows without dropping the partition itself.
--
-- Once DEFAULT is empty, PostgreSQL can create the monthly partitions
-- without encountering existing rows that violate the new partition
-- boundaries.
-- ============================================================

-- Step 2: empty the DEFAULT partition completely

TRUNCATE inventory_movements_default;


-- ============================================================
-- Step 3: Create Monthly Range Partitions
-- ============================================================
--
-- Dynamically creates one partition per month from January 2023
-- through August 2026.
--
-- Range semantics are:
--     FROM (month_start) TO (next_month_start)
--
-- The upper bound is exclusive, so each movement_date belongs to
-- exactly one monthly partition.
--
-- A DO block with dynamic SQL avoids manually writing dozens of
-- CREATE TABLE statements.
-- ============================================================

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


-- ============================================================
-- Step 4: Future Catch-All Partition
-- ============================================================
--
-- Handles every movement from 2026-09-01 onward.
--
-- This prevents new inserts from failing simply because a monthly
-- partition has not yet been created for a future date.
--
-- DESIGN NOTE:
-- This is a safety net, not a replacement for ongoing partition
-- management. Future data can later be migrated into monthly
-- partitions as they are created.
-- ============================================================

-- Step 4: catch-all future partition so new inserts never hit an error

CREATE TABLE inventory_movements_future PARTITION OF inventory_movements

    FOR VALUES FROM ('2026-09-01') TO (MAXVALUE);


-- ============================================================
-- Step 5: Reload Historical Data
-- ============================================================
--
-- Reinsert the preserved rows through the parent partitioned table.
--
-- PostgreSQL evaluates movement_date and automatically routes each
-- row to the appropriate monthly partition or the future partition.
--
-- This is important: the application does not need to know which
-- physical partition should receive a row.
-- ============================================================

-- Step 5: reload the data — Postgres now routes each row to its correct monthly

-- partition automatically based on movement_date

INSERT INTO inventory_movements

SELECT * FROM inventory_movements_temp;


-- ============================================================
-- Step 6: Remove Obsolete DEFAULT Partition
-- ============================================================
--
-- At this point the historical data has been redistributed into
-- the appropriate range partitions.
--
-- The old DEFAULT partition is no longer required, so it is detached
-- from the partition hierarchy and then dropped.
--
-- The temporary holding table is also removed because its purpose
-- was only to support the migration.
-- ============================================================

-- Step 6: clean up — detach and drop both the now-empty DEFAULT and the temp table

ALTER TABLE inventory_movements DETACH PARTITION inventory_movements_default;

DROP TABLE inventory_movements_default;

DROP TABLE inventory_movements_temp;