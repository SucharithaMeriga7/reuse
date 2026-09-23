-- ============================================================
-- Object Name : AEROSPACE_PARTS_SOURCE
-- Purpose     : Source table DDL for Aerospace Parts inventory data
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- ============================================================

CREATE TABLE IF NOT EXISTS AEROSPACE_PARTS_SOURCE (
    PART_NUMBER          VARCHAR        NOT NULL,
    PART_NAME            VARCHAR,
    PART_CATEGORY        VARCHAR,
    MANUFACTURER         VARCHAR,
    WEIGHT_KG            NUMBER(18,4),
    CERTIFICATION_STATUS VARCHAR,
    LEAD_TIME_DAYS       NUMBER,
    UNIT_PRICE_USD       NUMBER(18,2),
    QUANTITY_ON_HAND     NUMBER,
    SUPPLIER_ID          VARCHAR,
    UPDATED_AT           TIMESTAMP_NTZ  NOT NULL,
    CONSTRAINT PK_AEROSPACE_PARTS_SOURCE PRIMARY KEY (PART_NUMBER)
);