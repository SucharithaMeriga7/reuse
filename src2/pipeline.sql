-- ============================================================
-- Object Name : AEROSPACE_PARTS_INVENTORY_PIPELINE
-- Purpose     : Incremental/Full ETL pipeline: AEROSPACE_PARTS_SOURCE -> AEROSPACE_PARTS_TARGET
--               SCD Type 1 merge on PART_NUMBER | UPDATED_AT watermark | Soft delete | Reconciliation logging
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
-- [DELTA REFERENCE] Adapted from: AEROSPACE_PARTS_INVENTORY_PIPELINE (79% match, 5 deltas applied)
-- ============================================================
CREATE OR REPLACE PROCEDURE AEROSPACE_PARTS_INVENTORY_PIPELINE(P_MODE VARCHAR DEFAULT 'INCREMENTAL')
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_last_ts              TIMESTAMP_NTZ;
    v_load_mode            VARCHAR DEFAULT 'INCREMENTAL';
    v_source_count         NUMBER  DEFAULT 0;
    v_target_count         NUMBER  DEFAULT 0;
    v_inserted_count       NUMBER  DEFAULT 0;
    v_updated_count        NUMBER  DEFAULT 0;
    v_decommissioned_count NUMBER  DEFAULT 0;
    v_matched_count        NUMBER  DEFAULT 0;
BEGIN
    -- Section 1: Watermark Lookup -- Incremental Load Control
    IF (P_MODE = 'FULL') THEN
        v_last_ts   := '1900-01-01'::TIMESTAMP_NTZ;
        v_load_mode := 'FULL';
    ELSE
        SELECT COALESCE(MAX(RUN_TIMESTAMP), '1900-01-01'::TIMESTAMP_NTZ)
          INTO :v_last_ts
          FROM ETL_RECONCILIATION_LOG
         WHERE PIPELINE_NAME = 'AEROSPACE_PARTS_INVENTORY_PIPELINE'
           AND STATUS = 'COMPLETED';
        v_load_mode := 'INCREMENTAL';
    END IF;
    -- Section 2: Deduplication and Transformation -- Staging
    CREATE OR REPLACE TEMPORARY TABLE AEROSPACE_PARTS_STAGE AS
    SELECT
        PART_NUMBER,
        UPPER(MANUFACTURER)                 AS MANUFACTURER,      -- [DELTA MODIFY] MANUFACTURER: INITCAP -> UPPER per BRD RULE-006
        IFF(WEIGHT_KG <= 0, -1, WEIGHT_KG) AS WEIGHT_KG,         -- [DELTA MODIFY] WEIGHT_KG: CASE -> IFF sentinel -1 per BRD RULE-007
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        TRANSPORT_MODE,                                            -- [DELTA ADD] TRANSPORT_MODE: direct copy from source per BRD DEC-006 / AC-004
        UPDATED_AT,
        CASE
            WHEN CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60  THEN 'High Risk'
            WHEN CERTIFICATION_STATUS = 'Pending' OR  LEAD_TIME_DAYS > 100 THEN 'Medium Risk'
            WHEN CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 THEN 'Low Risk'
            ELSE 'Medium Risk'
        END AS RISK_SCORE
        -- [DELTA REMOVE] SUPPLIER_RATING, SOURCE_SYSTEM: not in BRD/STTM, removed per BRD-only scope guardrail
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC) AS RN
          FROM AEROSPACE_PARTS_SOURCE
         WHERE UPDATED_AT > :v_last_ts
    ) deduped
    WHERE RN = 1;
    -- Section 3: Pre-Merge Metrics
    SELECT COUNT(*) INTO :v_source_count   FROM AEROSPACE_PARTS_STAGE;
    SELECT COUNT(*) INTO :v_target_count   FROM AEROSPACE_PARTS_TARGET;
    SELECT COUNT(*) INTO :v_inserted_count FROM AEROSPACE_PARTS_STAGE stg
     WHERE NOT EXISTS (SELECT 1 FROM AEROSPACE_PARTS_TARGET tgt WHERE tgt.PART_NUMBER = stg.PART_NUMBER);
    SELECT COUNT(*) INTO :v_updated_count  FROM AEROSPACE_PARTS_STAGE stg
     WHERE     EXISTS (SELECT 1 FROM AEROSPACE_PARTS_TARGET tgt WHERE tgt.PART_NUMBER = stg.PART_NUMBER);
    v_matched_count := :v_source_count;
    -- Section 4: SCD Type 1 MERGE -- Business Key: PART_NUMBER
    MERGE INTO AEROSPACE_PARTS_TARGET tgt
    USING AEROSPACE_PARTS_STAGE src ON tgt.PART_NUMBER = src.PART_NUMBER
    WHEN MATCHED THEN UPDATE SET
        tgt.MANUFACTURER         = src.MANUFACTURER,
        tgt.WEIGHT_KG            = src.WEIGHT_KG,
        tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
        tgt.LEAD_TIME_DAYS       = src.LEAD_TIME_DAYS,
        tgt.TRANSPORT_MODE       = src.TRANSPORT_MODE,             -- [DELTA ADD] TRANSPORT_MODE: new target column per BRD DEC-006
        tgt.UPDATED_AT           = src.UPDATED_AT,
        tgt.RISK_SCORE           = src.RISK_SCORE,
        tgt.STATUS               = 'Active',                       -- [DELTA RENAME] RECORD_STATUS -> STATUS per BRD STTM target column
        tgt.DW_LOAD_TIMESTAMP    = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, MANUFACTURER, WEIGHT_KG, CERTIFICATION_STATUS,
        LEAD_TIME_DAYS, TRANSPORT_MODE, UPDATED_AT, RISK_SCORE,    -- [DELTA ADD] TRANSPORT_MODE added to INSERT column list per BRD DEC-006
        STATUS, DW_LOAD_TIMESTAMP
    ) VALUES (
        src.PART_NUMBER, src.MANUFACTURER, src.WEIGHT_KG, src.CERTIFICATION_STATUS,
        src.LEAD_TIME_DAYS, src.TRANSPORT_MODE, src.UPDATED_AT, src.RISK_SCORE,
        'Active', CURRENT_TIMESTAMP()
    );
    -- Section 5: Soft Delete -- Decommission Absent Parts
    UPDATE AEROSPACE_PARTS_TARGET
       SET STATUS            = 'Decommissioned',                   -- [DELTA RENAME] RECORD_STATUS -> STATUS per BRD STTM
           DW_LOAD_TIMESTAMP = CURRENT_TIMESTAMP()
     WHERE STATUS <> 'Decommissioned'
       AND PART_NUMBER NOT IN (SELECT PART_NUMBER FROM AEROSPACE_PARTS_SOURCE);
    v_decommissioned_count := SQLROWCOUNT;
    -- Section 6: Reconciliation Logging -- Mandatory Per Run
    INSERT INTO ETL_RECONCILIATION_LOG (
        RECON_ID, PIPELINE_NAME, RUN_TIMESTAMP, SOURCE_COUNT, TARGET_COUNT,
        MATCHED_COUNT, INSERTED_COUNT, UPDATED_COUNT, DECOMMISSIONED_COUNT,
        LOAD_MODE, STATUS, NOTES
    ) VALUES (
        UUID_STRING(), 'AEROSPACE_PARTS_INVENTORY_PIPELINE', CURRENT_TIMESTAMP(),
        :v_source_count, :v_target_count, :v_matched_count,
        :v_inserted_count, :v_updated_count, :v_decommissioned_count,
        :v_load_mode, 'COMPLETED',
        'Pipeline completed successfully. Mode: ' || :v_load_mode
    );
    RETURN 'SUCCESS: Mode=' || :v_load_mode
        || ' | Source='         || :v_source_count::VARCHAR
        || ' | Inserted='       || :v_inserted_count::VARCHAR
        || ' | Updated='        || :v_updated_count::VARCHAR
        || ' | Decommissioned=' || :v_decommissioned_count::VARCHAR;
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO ETL_RECONCILIATION_LOG (
            RECON_ID, PIPELINE_NAME, RUN_TIMESTAMP, SOURCE_COUNT, TARGET_COUNT,
            MATCHED_COUNT, INSERTED_COUNT, UPDATED_COUNT, DECOMMISSIONED_COUNT,
            LOAD_MODE, STATUS, NOTES
        ) VALUES (
            UUID_STRING(), 'AEROSPACE_PARTS_INVENTORY_PIPELINE', CURRENT_TIMESTAMP(),
            :v_source_count, :v_target_count, 0, 0, 0, 0,
            :v_load_mode, 'FAILED',
            'Pipeline failed: ' || SQLERRM
        );
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;