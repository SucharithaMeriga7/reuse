-- ============================================================
-- Object Name : AEROSPACE_PARTS_INVENTORY_PIPELINE
-- Purpose     : SCD Type 1 incremental pipeline from AEROSPACE_PARTS_SOURCE
--               to AEROSPACE_PARTS_TARGET with deduplication, transformations,
--               RISK_SCORE derivation, soft delete, and reconciliation logging
-- Author      : SUCHARITHAS
-- Generated   : 2026-09-24
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

    -- --------------------------------------------------------
    -- Section 1: Watermark Lookup - Incremental Load Control
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    -- Section 2: Deduplication and Transformation - Staging
    -- --------------------------------------------------------
    CREATE OR REPLACE TEMPORARY TABLE AEROSPACE_PARTS_STAGE AS
    SELECT
        PART_NUMBER,
        PART_NAME,
        PART_CATEGORY,
        INITCAP(MANUFACTURER)                                        AS MANUFACTURER,
        IFF(WEIGHT_KG <= 0, -1, WEIGHT_KG)                          AS WEIGHT_KG,
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        ROUND(UNIT_PRICE_USD, 2)                                     AS UNIT_PRICE_USD,
        QUANTITY_ON_HAND,
        SUPPLIER_ID,
        UPDATED_AT,
        CASE
            WHEN CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60
                THEN 'High Risk'
            WHEN CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100
                THEN 'Medium Risk'
            WHEN CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual') AND LEAD_TIME_DAYS <= 60
                THEN 'Low Risk'
            ELSE 'Medium Risk'
        END                                                          AS RISK_SCORE
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC) AS RN
          FROM AEROSPACE_PARTS_SOURCE
         WHERE UPDATED_AT > :v_last_ts
    ) deduped
    WHERE RN = 1;

    -- --------------------------------------------------------
    -- Section 3: Pre-Merge Metrics
    -- --------------------------------------------------------
    SELECT COUNT(*) INTO :v_source_count FROM AEROSPACE_PARTS_STAGE;
    SELECT COUNT(*) INTO :v_target_count FROM AEROSPACE_PARTS_TARGET;

    SELECT COUNT(*)
      INTO :v_inserted_count
      FROM AEROSPACE_PARTS_STAGE stg
     WHERE NOT EXISTS (
         SELECT 1 FROM AEROSPACE_PARTS_TARGET tgt
          WHERE tgt.PART_NUMBER = stg.PART_NUMBER
     );

    SELECT COUNT(*)
      INTO :v_updated_count
      FROM AEROSPACE_PARTS_STAGE stg
     WHERE EXISTS (
         SELECT 1 FROM AEROSPACE_PARTS_TARGET tgt
          WHERE tgt.PART_NUMBER = stg.PART_NUMBER
     );

    v_matched_count := :v_source_count;

    -- --------------------------------------------------------
    -- Section 4: SCD Type 1 MERGE - Business Key: PART_NUMBER
    -- --------------------------------------------------------
    MERGE INTO AEROSPACE_PARTS_TARGET tgt
    USING AEROSPACE_PARTS_STAGE src
       ON tgt.PART_NUMBER = src.PART_NUMBER
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME            = src.PART_NAME,
        tgt.PART_CATEGORY        = src.PART_CATEGORY,
        tgt.MANUFACTURER         = src.MANUFACTURER,
        tgt.WEIGHT_KG            = src.WEIGHT_KG,
        tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
        tgt.LEAD_TIME_DAYS       = src.LEAD_TIME_DAYS,
        tgt.UNIT_PRICE_USD       = src.UNIT_PRICE_USD,
        tgt.QUANTITY_ON_HAND     = src.QUANTITY_ON_HAND,
        tgt.SUPPLIER_ID          = src.SUPPLIER_ID,
        tgt.UPDATED_AT           = src.UPDATED_AT,
        tgt.RISK_SCORE           = src.RISK_SCORE,
        tgt.STATUS               = 'Active',
        tgt.LOAD_TIMESTAMP       = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, PART_NAME, PART_CATEGORY, MANUFACTURER,
        WEIGHT_KG, CERTIFICATION_STATUS, LEAD_TIME_DAYS,
        UNIT_PRICE_USD, QUANTITY_ON_HAND, SUPPLIER_ID,
        UPDATED_AT, RISK_SCORE, STATUS, LOAD_TIMESTAMP
    ) VALUES (
        src.PART_NUMBER, src.PART_NAME, src.PART_CATEGORY, src.MANUFACTURER,
        src.WEIGHT_KG, src.CERTIFICATION_STATUS, src.LEAD_TIME_DAYS,
        src.UNIT_PRICE_USD, src.QUANTITY_ON_HAND, src.SUPPLIER_ID,
        src.UPDATED_AT, src.RISK_SCORE, 'Active', CURRENT_TIMESTAMP()
    );

    -- --------------------------------------------------------
    -- Section 5: Soft Delete - Decommission Absent Parts
    -- --------------------------------------------------------
    UPDATE AEROSPACE_PARTS_TARGET
       SET STATUS         = 'Decommissioned',
           LOAD_TIMESTAMP = CURRENT_TIMESTAMP()
     WHERE STATUS <> 'Decommissioned'
       AND PART_NUMBER NOT IN (SELECT PART_NUMBER FROM AEROSPACE_PARTS_SOURCE);

    v_decommissioned_count := SQLROWCOUNT;

    -- --------------------------------------------------------
    -- Section 6: Reconciliation Logging
    -- --------------------------------------------------------
    INSERT INTO ETL_RECONCILIATION_LOG (
        RECON_ID, PIPELINE_NAME, RUN_TIMESTAMP,
        SOURCE_COUNT, TARGET_COUNT, MATCHED_COUNT,
        INSERTED_COUNT, UPDATED_COUNT, DECOMMISSIONED_COUNT,
        LOAD_MODE, STATUS, NOTES
    ) VALUES (
        UUID_STRING(),
        'AEROSPACE_PARTS_INVENTORY_PIPELINE',
        CURRENT_TIMESTAMP(),
        :v_source_count,
        :v_target_count,
        :v_matched_count,
        :v_inserted_count,
        :v_updated_count,
        :v_decommissioned_count,
        :v_load_mode,
        'COMPLETED',
        'Pipeline completed successfully. Mode: ' || :v_load_mode
    );

    RETURN 'SUCCESS: Mode=' || :v_load_mode
        || ' | Source=' || :v_source_count::VARCHAR
        || ' | Inserted=' || :v_inserted_count::VARCHAR
        || ' | Updated=' || :v_updated_count::VARCHAR
        || ' | Decommissioned=' || :v_decommissioned_count::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        INSERT INTO ETL_RECONCILIATION_LOG (
            RECON_ID, PIPELINE_NAME, RUN_TIMESTAMP,
            SOURCE_COUNT, TARGET_COUNT, MATCHED_COUNT,
            INSERTED_COUNT, UPDATED_COUNT, DECOMMISSIONED_COUNT,
            LOAD_MODE, STATUS, NOTES
        ) VALUES (
            UUID_STRING(),
            'AEROSPACE_PARTS_INVENTORY_PIPELINE',
            CURRENT_TIMESTAMP(),
            :v_source_count,
            :v_target_count,
            0, 0, 0, 0,
            :v_load_mode,
            'FAILED',
            'Pipeline failed: ' || SQLERRM
        );
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;