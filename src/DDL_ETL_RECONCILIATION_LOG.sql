-- ============================================================
-- Object Name : ETL_RECONCILIATION_LOG
-- Purpose     : Reconciliation audit log for all pipeline run metrics
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================

CREATE TABLE IF NOT EXISTS ETL_RECONCILIATION_LOG (
    RECON_ID             VARCHAR        NOT NULL DEFAULT UUID_STRING(),
    PIPELINE_NAME        VARCHAR        NOT NULL,
    RUN_TIMESTAMP        TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_COUNT         NUMBER         NOT NULL DEFAULT 0,
    TARGET_COUNT         NUMBER         NOT NULL DEFAULT 0,
    MATCHED_COUNT        NUMBER         NOT NULL DEFAULT 0,
    INSERTED_COUNT       NUMBER         NOT NULL DEFAULT 0,
    UPDATED_COUNT        NUMBER         NOT NULL DEFAULT 0,
    DECOMMISSIONED_COUNT NUMBER         NOT NULL DEFAULT 0,
    LOAD_MODE            VARCHAR,
    STATUS               VARCHAR        NOT NULL DEFAULT 'COMPLETED',
    NOTES                VARCHAR,
    CONSTRAINT PK_ETL_RECONCILIATION_LOG PRIMARY KEY (RECON_ID)
);