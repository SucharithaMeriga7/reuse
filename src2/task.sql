-- ============================================================
-- Object Name : AEROSPACE_PARTS_INVENTORY_TASK
-- Purpose     : Scheduled task -- Daily at 03:00 UTC
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================
CREATE OR REPLACE TASK AEROSPACE_PARTS_INVENTORY_TASK
  WAREHOUSE = SNOWFLAKE_LEARNING_WH
  SCHEDULE  = 'USING CRON 0 3 * * * UTC'
AS CALL AEROSPACE_PARTS_INVENTORY_PIPELINE('INCREMENTAL');