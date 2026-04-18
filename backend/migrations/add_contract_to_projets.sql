-- Migration: Add contract fields to projets table
-- Run this in your MySQL client

ALTER TABLE projets
  ADD COLUMN IF NOT EXISTS contract_url VARCHAR(500) NULL COMMENT 'Relative path to the uploaded contract file',
  ADD COLUMN IF NOT EXISTS contract_filename VARCHAR(255) NULL COMMENT 'Original filename of the uploaded contract',
  ADD COLUMN IF NOT EXISTS contract_uploaded_at DATETIME NULL COMMENT 'Timestamp when the contract was uploaded';
