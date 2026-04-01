-- Migration: Add base_salary to employees table
ALTER TABLE employees ADD COLUMN base_salary DECIMAL(15,2) DEFAULT 0.00 AFTER statut;
