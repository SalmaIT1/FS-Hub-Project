-- Create the database
CREATE DATABASE IF NOT EXISTS fs_hub_db;

-- Use the database
USE fs_hub_db;

-- Table structure for users (Authentication)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('Admin', 'RH', 'Employé') DEFAULT 'Employé',
    permissions TEXT,
    dernierLogin DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Table structure for employees
CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE, -- Link to users table
    matricule VARCHAR(20) NOT NULL UNIQUE,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    dateNaissance DATE,
    sexe ENUM('Homme', 'Femme'),
    photo VARCHAR(255),
    email VARCHAR(100) NOT NULL UNIQUE,
    telephone VARCHAR(20),
    adresse TEXT,
    ville VARCHAR(100),
    poste VARCHAR(100),
    departement VARCHAR(100),
    dateEmbauche DATE,
    typeContrat ENUM('CDI', 'CDD', 'Stage', 'Freelance'),
    statut ENUM('Actif', 'Suspendu', 'Démission') DEFAULT 'Actif',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Table structure for password resets
CREATE TABLE IF NOT EXISTS password_resets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    code VARCHAR(6) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL
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
    DECLARE v_user_id INT;
    
    -- 1. Create the user account
    INSERT INTO users (username, password, role, permissions) 
    VALUES (p_username, p_password, p_role, p_permissions);
    
    -- 2. Get the new user ID
    SET v_user_id = LAST_INSERT_ID();
    
    -- 3. Create the employee record linked to that user
    INSERT INTO employees (
        user_id, matricule, nom, prenom, dateNaissance, sexe, photo,
        email, telephone, adresse, ville, poste, departement,
        dateEmbauche, typeContrat, statut
    )
    VALUES (
        v_user_id, p_matricule, p_nom, p_prenom, p_dateNaissance, p_sexe, p_photo,
        p_email, p_telephone, p_adresse, p_ville, p_poste, p_departement,
        p_dateEmbauche, p_typeContrat, p_statut
    );
    
    -- 4. Return the employee ID
    SELECT LAST_INSERT_ID() AS employee_id;
END //

DELIMITER ;

-- Create Initial Admin Account
-- Note: In production, password should be hashed using the application logic.
CALL CreateEmployeeWithUser(
    'admin',                         -- username
    '@ForeverSoftware2026',          -- password
    'Admin',                         -- role
    NULL,                            -- permissions
    'ADM-001',                       -- matricule
    'Admin',                         -- nom
    'System',                        -- prenom
    '1990-01-01',                    -- dateNaissance
    'Homme',                         -- sexe
    NULL,                            -- photo
    'admin@fshub.com',               -- email
    '+21200000000',                  -- telephone
    '123 Rue Principale',            -- adresse
    'Casablanca',                    -- ville
    'System Administrator',          -- poste
    'IT',                            -- departement
    '2020-01-01',                    -- dateEmbauche
    'CDI',                           -- typeContrat
    'Actif'                          -- statut
);
