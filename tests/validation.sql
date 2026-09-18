-- Run in Databricks SQL after the job succeeds.
-- Replace _dev with _prod when validating production.

-- Test 1: all ten XML source documents reached Bronze.
SELECT COUNT(*) AS bronze_document_count
FROM main.bronze_dev.xml_raw;
-- Expected: 10

-- Test 2: the duplicate id=1001 was merged, so Silver has nine business rows.
SELECT COUNT(*) AS silver_record_count
FROM main.silver_dev.xml_records;
-- Expected: 9

-- Test 3: the newest duplicate value won.
SELECT id, name, email, updated_at, source_file
FROM main.silver_dev.xml_records
WHERE id = 1001;
-- Expected name: Ada Lovelace; source_file ends in customer-010-duplicate.xml

-- Test 4: the supplied clean files have no quarantine records.
SELECT COUNT(*) AS quarantined_record_count
FROM main.silver_dev.xml_quarantine;
-- Expected: 0 (the table may not exist until a bad record is encountered)

-- Test 5: inspect the raw, replayable payload and lineage in Bronze.
SELECT source_file, ingested_at, raw_xml
FROM main.bronze_dev.xml_raw
ORDER BY source_file;
