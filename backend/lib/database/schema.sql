-- Initial database schema for fs_hub (MySQL)
-- Automatically applied by the backend if the 'users' table is missing.

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(50) PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('Admin', 'RH', 'Employé') DEFAULT 'Employé',
    permissions TEXT,
    dernierLogin DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen DATETIME NULL
);

CREATE TABLE IF NOT EXISTS employees (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) UNIQUE,
    matricule VARCHAR(20) NOT NULL UNIQUE,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    dateNaissance DATE,
    sexe ENUM('Homme', 'Femme'),
    photo LONGTEXT,
    email VARCHAR(100) NOT NULL UNIQUE,
    telephone VARCHAR(20),
    adresse TEXT,
    ville VARCHAR(100),
    poste VARCHAR(100),
    departement VARCHAR(100),
    dateEmbauche DATE,
    typeContrat ENUM('CDI', 'CDD', 'Stage', 'Freelance'),
    statut ENUM('actif', 'inactif', 'suspendu') DEFAULT 'actif',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    token VARCHAR(1024) NOT NULL,
    revoked BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Note: The admin user should be created via the API or a separate script to ensure correct BCrypt hashing.
-- However, we can insert a default admin with a known hash if needed.
-- Password: @ForeverSoftware2026
INSERT IGNORE INTO users (id, username, password, role) 
VALUES ('admin-uuid-001', 'admin', '$2a$10$VyhT7gdlBgt2HjqQ8ng.5OHqw3MxkZFXhu9AcOjyCTlKeNQovNKAu', 'Admin');

INSERT IGNORE INTO employees (id, user_id, matricule, nom, prenom, email, poste, departement, statut)
VALUES ('admin-uuid-001', 'admin-uuid-001', 'ADM-001', 'Admin', 'System', 'admin@fshub.com', 'System Administrator', 'IT', 'actif');
