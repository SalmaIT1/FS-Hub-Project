-- ============================================================
-- Migration: Idempotency Keys (P9 Missing Component)
-- Purpose  : Track X-Idempotency-Key headers to prevent
--            duplicate processing of POST/PUT requests.
-- ============================================================

CREATE TABLE IF NOT EXISTS idempotency_keys (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(50),
    response_code INT,
    response_body LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    INDEX idx_user_key (user_id, id)
);
