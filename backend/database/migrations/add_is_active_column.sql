-- Migration: Add is_active column to employees table
-- This should be run on existing databases to add the missing is_active column

ALTER TABLE employees ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
