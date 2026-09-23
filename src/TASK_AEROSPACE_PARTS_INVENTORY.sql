-- ============================================================
-- Object Name : TASK_AEROSPACE_PARTS_INVENTORY
-- Purpose     : Scheduled task - Daily at 03:00 UTC for AEROSPACE_PARTS_INVENTORY_PIPELINE
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================

CREATE OR REPLACE TASK TASK_AEROSPACE_PARTS_INVENTORY
  WAREHOUSE = SNOWFLAKE_LEARNING_WH
  SCHEDULE = 'USING CRON 0 3 * * * UTC'
AS CALL AEROSPACE_PARTS_INVENTORY_PIPELINE('INCREMENTAL');