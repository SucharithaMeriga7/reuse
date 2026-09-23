-- ============================================================
-- Object Name : AEROSPACE_PARTS_INVENTORY_PIPELINE_TASK
-- Purpose     : Scheduled task - daily at 03:00 UTC
--               Calls AEROSPACE_PARTS_INVENTORY_PIPELINE
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================
CREATE OR REPLACE TASK AEROSPACE_PARTS_INVENTORY_PIPELINE_TASK
  WAREHOUSE = SNOWFLAKE_LEARNING_WH
  SCHEDULE = 'USING CRON 0 3 * * * UTC'
AS CALL AEROSPACE_PARTS_INVENTORY_PIPELINE('INCREMENTAL');