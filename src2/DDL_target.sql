-- ============================================================
-- Object Name : AEROSPACE_PARTS_TARGET
-- Purpose     : Target table delta -- [DELTA ADD] TRANSPORT_MODE per BRD DEC-006 / AC-004
--               Note: STATUS column already present in table (verified via schema probe)
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================
ALTER TABLE AEROSPACE_PARTS_TARGET ADD COLUMN TRANSPORT_MODE VARCHAR(100);