-- ============================================================
-- Object Name : ETL_RECONCILIATION_LOG
-- Purpose     : Reconciliation audit log for aerospace parts pipeline runs
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================
CREATE TABLE IF NOT EXISTS ETL_RECONCILIATION_LOG (
    RECON_ID              VARCHAR(36)     NOT NULL DEFAULT UUID_STRING(),
    PIPELINE_NAME         VARCHAR(200)    NOT NULL,
    RUN_TIMESTAMP         TIMESTAMP_NTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_COUNT          NUMBER(12)      DEFAULT 0,
    TARGET_COUNT          NUMBER(12)      DEFAULT 0,
    MATCHED_COUNT         NUMBER(12)      DEFAULT 0,
    INSERTED_COUNT        NUMBER(12)      DEFAULT 0,
    UPDATED_COUNT         NUMBER(12)      DEFAULT 0,
    DECOMMISSIONED_COUNT  NUMBER(12)      DEFAULT 0,
    LOAD_MODE             VARCHAR(20),
    STATUS                VARCHAR(20),
    NOTES                 VARCHAR(2000)
);