-- ============================================================
-- Migration: System Settings (P2 Remediation)
-- Purpose  : Store global configuration values (tax rates, etc.)
--            to avoid hardcoded logic in backend repositories.
-- ============================================================

CREATE TABLE IF NOT EXISTS system_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value VARCHAR(500) NOT NULL,
    description VARCHAR(255),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Seed initial financial parameters
INSERT INTO system_settings (setting_key, setting_value, description) VALUES
('finance_timbre_fiscal', '1.000', 'Tax stamp amount for invoices (TND)'),
('finance_tva_default', '19.0', 'Default TVA percentage'),
('hr_cnss_rate', '0.0918', 'CNSS employee contribution rate')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);
