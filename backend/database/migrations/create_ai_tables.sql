-- FS-Hub AI Decision Support System — schema (idempotent fragments; also applied via migrations.dart)

CREATE TABLE IF NOT EXISTS ai_feature_snapshots (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    entity_type ENUM('project','task','invoice','client','employee','expense') NOT NULL,
    entity_id VARCHAR(64) NOT NULL,
    feature_version VARCHAR(20) NOT NULL DEFAULT 'v1',
    features_json JSON NOT NULL,
    feature_hash CHAR(64) NOT NULL,
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ai_feat_entity (entity_type, entity_id, captured_at)
);

CREATE TABLE IF NOT EXISTS ai_predictions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    model_name VARCHAR(64) NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    entity_type ENUM('project','task','invoice','client','employee','expense') NOT NULL,
    entity_id VARCHAR(64) NOT NULL,
    prediction_type VARCHAR(64) NOT NULL,
    score DECIMAL(8,6) NULL,
    label_predicted VARCHAR(32) NULL,
    confidence DECIMAL(5,4) NULL,
    explanation_json JSON NULL,
    requested_by VARCHAR(50) NULL,
    inference_mode ENUM('realtime','batch') DEFAULT 'realtime',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ai_pred_lookup (entity_type, entity_id, prediction_type, created_at)
);

CREATE TABLE IF NOT EXISTS ai_model_registry (
    id INT AUTO_INCREMENT PRIMARY KEY,
    problem_code VARCHAR(64) NOT NULL,
    version VARCHAR(20) NOT NULL,
    artifact_path VARCHAR(512) NOT NULL,
    metrics_json JSON NOT NULL,
    feature_schema_json JSON NOT NULL,
    status ENUM('staging','production','retired') DEFAULT 'staging',
    trained_at DATETIME NOT NULL,
    promoted_at DATETIME NULL,
    UNIQUE KEY uk_ai_problem_version (problem_code, version)
);

CREATE TABLE IF NOT EXISTS ai_training_runs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    problem_code VARCHAR(64) NOT NULL,
    dataset_snapshot_id VARCHAR(64) NULL,
    row_count INT NULL,
    metrics_json JSON NULL,
    status ENUM('running','success','failed') NOT NULL,
    error_message TEXT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS ai_kpi_daily (
    kpi_date DATE NOT NULL,
    kpi_code VARCHAR(64) NOT NULL,
    dimension_key VARCHAR(128) NOT NULL DEFAULT 'global',
    value_decimal DECIMAL(18,4) NULL,
    value_json JSON NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (kpi_date, kpi_code, dimension_key)
);

CREATE TABLE IF NOT EXISTS ai_prediction_feedback (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    prediction_id BIGINT NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    is_accurate TINYINT(1) NOT NULL,
    comment TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (prediction_id) REFERENCES ai_predictions(id) ON DELETE CASCADE
);
