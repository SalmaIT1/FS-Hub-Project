-- Create the database
CREATE DATABASE IF NOT EXISTS fs_hub_db;

-- Use the database
USE fs_hub_db;

-- Table structure for users (Authentication)
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(50) PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('Admin', 'RH', 'Employé', 'Comptable', 'Manager') DEFAULT 'Employé',
    permissions TEXT,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen DATETIME NULL,
    dernierLogin DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Table structure for employees
CREATE TABLE IF NOT EXISTS employees (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) UNIQUE, -- Link to users table
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
    base_salary DECIMAL(12,2) DEFAULT 0.00,
    dateEmbauche DATE,
    typeContrat ENUM('CDI', 'CDD', 'Stage', 'Freelance'),
    statut ENUM('actif', 'inactif', 'suspendu') DEFAULT 'actif',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Table structure for password resets
CREATE TABLE IF NOT EXISTS password_resets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Table structure for clients
CREATE TABLE IF NOT EXISTS clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(150),
    prenom VARCHAR(150),
    raison_sociale VARCHAR(200),
    email VARCHAR(150),
    telephone VARCHAR(20),
    type ENUM('Entreprise','Particulier'),
    solde_du DECIMAL(12,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Note on automatic creation:
-- In a real application, you would typically handle this in your backend logic 
-- (create user first, then employee). However, if you want a trigger to 
-- automate this, you would need to pass user credentials through the employee 
-- insert, which requires those columns to exist in 'employees' as well.
-- Below is a stored procedure approach which is cleaner for Workbench:

DELIMITER //

CREATE PROCEDURE CreateEmployeeWithUser(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_role VARCHAR(20),
    IN p_permissions TEXT,
    IN p_matricule VARCHAR(20),
    IN p_nom VARCHAR(100),
    IN p_prenom VARCHAR(100),
    IN p_dateNaissance DATE,
    IN p_sexe VARCHAR(10),
    IN p_photo LONGTEXT,
    IN p_email VARCHAR(100),
    IN p_telephone VARCHAR(20),
    IN p_adresse TEXT,
    IN p_ville VARCHAR(100),
    IN p_poste VARCHAR(100),
    IN p_departement VARCHAR(100),
    IN p_dateEmbauche DATE,
    IN p_typeContrat VARCHAR(20),
    IN p_statut VARCHAR(20)
)
BEGIN
    DECLARE v_user_id VARCHAR(50);
    DECLARE v_emp_id VARCHAR(50);
    
    SET v_user_id = UUID();
    SET v_emp_id = UUID();
    
    -- 1. Create the user account
    INSERT INTO users (id, username, password, role, permissions) 
    VALUES (v_user_id, p_username, p_password, p_role, p_permissions);
    
    -- 2. Create the employee record linked to that user
    INSERT INTO employees (
        id, user_id, matricule, nom, prenom, dateNaissance, sexe, photo,
        email, telephone, adresse, ville, poste, departement,
        dateEmbauche, typeContrat, statut
    )
    VALUES (
        v_emp_id, v_user_id, p_matricule, p_nom, p_prenom, p_dateNaissance, p_sexe, p_photo,
        p_email, p_telephone, p_adresse, p_ville, p_poste, p_departement,
        p_dateEmbauche, p_typeContrat, p_statut
    );
    
    -- 3. Return the employee ID
    SELECT v_emp_id AS employee_id;
END //

DELIMITER ;

-- ⚠️  SECURITY: Admin account seed — P0-4 FIX
-- The plaintext password has been REMOVED from this file to prevent credential
-- exposure in version control. The sentinel value 'INITIAL_SETUP_REQUIRED' is
-- intentionally not a valid BCrypt hash, so the account cannot be logged into
-- until a real password is set through the backend reset flow.
--
-- HOW TO SET THE ADMIN PASSWORD (do this before first production use):
--   1. Start the backend server.
--   2. Call POST /v1/auth/forgot-password with body: { "username": "admin" }
--   3. The reset link/token will be emailed to admin@fshub.com.
--   4. Use that token with POST /v1/auth/reset-password to set a strong password.
--
-- Alternatively, use the backend console to call AuthService.createUser()
-- directly, which properly BCrypt-hashes the password before storage.
CALL CreateEmployeeWithUser(
    'admin',                         -- username
    'INITIAL_SETUP_REQUIRED',        -- SENTINEL — not a valid BCrypt hash → login disabled until set via reset flow
    'Admin',                         -- role
    NULL,                            -- permissions
    'ADM-001',                       -- matricule
    'Admin',                         -- nom
    'System',                        -- prenom
    '1990-01-01',                    -- dateNaissance
    'Homme',                         -- sexe
    NULL,                            -- photo
    'admin@fshub.com',               -- email (used for password reset)
    '+21200000000',                  -- telephone
    '123 Rue Principale',            -- adresse
    'Casablanca',                    -- ville
    'System Administrator',          -- poste
    'IT',                            -- departement
    '2020-01-01',                    -- dateEmbauche
    'CDI',                           -- typeContrat
    'Actif'                          -- statut
);

-- Seed System Bot User (Reserved SYSTEM_ID)
-- This record is the authoritative identity for system-generated chat messages and audit logs.
INSERT INTO users (id, username, password, role, is_online, is_active) 
VALUES ('00000000-0000-0000-0000-000000000000', 'SYSTEM', 'DISABLED_ACCOUNT', 'Admin', FALSE, TRUE)
ON DUPLICATE KEY UPDATE username = 'SYSTEM', is_active = TRUE;
