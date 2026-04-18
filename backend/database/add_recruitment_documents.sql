-- =====================================================
-- Migration: Add Recruitment Document Columns to Employees
-- =====================================================
-- Run this against your MySQL database.

ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS cin_document              TEXT          NULL COMMENT 'URL/path to CIN copy',
  ADD COLUMN IF NOT EXISTS cv_document               TEXT          NULL COMMENT 'URL/path to CV',
  ADD COLUMN IF NOT EXISTS bac_document              TEXT          NULL COMMENT 'URL/path to BAC certificate',
  ADD COLUMN IF NOT EXISTS degree_document           TEXT          NULL COMMENT 'URL/path to Licence/Master/Ingenierie degree',
  ADD COLUMN IF NOT EXISTS transcripts_documents     TEXT          NULL COMMENT 'URL/path(s) to university transcripts (comma-separated or JSON array)';

-- =====================================================
-- Verify
-- =====================================================
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'employees'
  AND COLUMN_NAME IN ('cin_document','cv_document','bac_document','degree_document','transcripts_documents');
