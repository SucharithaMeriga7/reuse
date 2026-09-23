-- ============================================================
-- Object Name : TASK_AEROSPACE_PARTS_INVENTORY_PIPELINE
-- Purpose     : Scheduled task — daily at 04:00 UTC for AEROSPACE_PARTS_INVENTORY_PIPELINE
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================
CREATE OR REPLACE TASK TASK_AEROSPACE_PARTS_INVENTORY_PIPELINE
  WAREHOUSE = SNOWFLAKE_LEARNING_WH
  SCHEDULE = 'USING CRON 0 4 * * * UTC'
AS CALL AEROSPACE_PARTS_INVENTORY_PIPELINE('INCREMENTAL');