-- ============================================================
-- Object Name : AEROSPACE_PARTS_TARGET
-- Purpose     : Target table DDL for aerospace parts inventory analytics layer
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================
CREATE TABLE IF NOT EXISTS AEROSPACE_PARTS_TARGET (
    PART_NUMBER          VARCHAR(100)    NOT NULL,
    PART_NAME            VARCHAR(500)    NOT NULL,
    PART_CATEGORY        VARCHAR(200),
    MANUFACTURER         VARCHAR(300)    NOT NULL,
    WEIGHT_KG            NUMBER(12,4)    NOT NULL,
    LEAD_TIME_DAYS       NUMBER(10),
    CERTIFICATION_STATUS VARCHAR(50),
    UNIT_PRICE_USD       NUMBER(18,2),
    STOCK_QUANTITY       NUMBER(12),
    SUPPLIER_ID          VARCHAR(100),
    UPDATED_AT           TIMESTAMP_NTZ   NOT NULL,
    RISK_SCORE           VARCHAR(20)     NOT NULL,
    RECORD_STATUS        VARCHAR(20)     NOT NULL DEFAULT 'Active',
    ETL_LOAD_TIMESTAMP   TIMESTAMP_NTZ   NOT NULL
);