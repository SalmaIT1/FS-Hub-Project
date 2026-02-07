-- FS Hub Complete Database Schema

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

-- Table structure for demands
CREATE TABLE IF NOT EXISTS demands (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    requester_id VARCHAR(50) NOT NULL,
    status ENUM('pending', 'approved', 'rejected', 'resolved', 'in_progress') DEFAULT 'pending',
    handled_by VARCHAR(50) NULL,
    resolution_notes TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Table structure for notifications
CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_user_read (user_id, is_read),
    INDEX idx_user_timestamp (user_id, timestamp)
);

-- Table structure for password resets
CREATE TABLE IF NOT EXISTS password_resets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    code VARCHAR(6) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL
);

-- Chat System Database Schema

-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NULL, -- NULL for 1-1 conversations, name for groups
    avatar_url VARCHAR(500) NULL,
    type ENUM('direct', 'group') NOT NULL DEFAULT 'direct',
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_archived BOOLEAN DEFAULT FALSE,
    last_message_id INT NULL,
    last_message_at TIMESTAMP NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (last_message_id) REFERENCES messages(id) ON DELETE SET NULL,
    INDEX idx_type (type),
    INDEX idx_created_by (created_by),
    INDEX idx_last_message_at (last_message_at)
);

-- Conversation members table
CREATE TABLE IF NOT EXISTS conversation_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    conversation_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('admin', 'member') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP NULL,
    is_muted BOOLEAN DEFAULT FALSE,
    last_read_message_id INT NULL,
    last_read_at TIMESTAMP NULL,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (last_read_message_id) REFERENCES messages(id) ON DELETE SET NULL,
    UNIQUE KEY unique_conversation_user (conversation_id, user_id),
    INDEX idx_conversation_id (conversation_id),
    INDEX idx_user_id (user_id),
    INDEX idx_last_read_at (last_read_at)
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    conversation_id INT NOT NULL,
    sender_id INT NOT NULL,
    content TEXT NULL,
    type ENUM('text', 'file', 'voice', 'system') DEFAULT 'text',
    reply_to_id INT NULL,
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reply_to_id) REFERENCES messages(id) ON DELETE SET NULL,
    INDEX idx_conversation_id (conversation_id),
    INDEX idx_sender_id (sender_id),
    INDEX idx_created_at (created_at),
    INDEX idx_reply_to_id (reply_to_id),
    INDEX idx_conversation_created (conversation_id, created_at DESC)
);

-- Message attachments table
CREATE TABLE IF NOT EXISTS message_attachments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    thumbnail_path VARCHAR(500) NULL,
    metadata JSON NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    INDEX idx_message_id (message_id),
    INDEX idx_mime_type (mime_type)
);

-- Message reads table (read receipts)
CREATE TABLE IF NOT EXISTS message_reads (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    user_id INT NOT NULL,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_message_user_read (message_id, user_id),
    INDEX idx_message_id (message_id),
    INDEX idx_user_id (user_id),
    INDEX idx_read_at (read_at)
);

-- Message reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    user_id INT NOT NULL,
    emoji VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_message_user_emoji (message_id, user_id, emoji),
    INDEX idx_message_id (message_id),
    INDEX idx_user_id (user_id)
);

-- Typing events table (for real-time typing indicators)
CREATE TABLE IF NOT EXISTS typing_events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    conversation_id INT NOT NULL,
    user_id INT NOT NULL,
    is_typing BOOLEAN DEFAULT TRUE,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_conversation_user (conversation_id, user_id),
    INDEX idx_conversation_id (conversation_id),
    INDEX idx_user_id (user_id),
    INDEX idx_last_seen_at (last_seen_at)
);

-- File uploads table (for secure file management)
CREATE TABLE IF NOT EXISTS file_uploads (
    id INT AUTO_INCREMENT PRIMARY KEY,
    original_filename VARCHAR(255) NOT NULL,
    stored_filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    uploaded_by INT NOT NULL,
    is_public BOOLEAN DEFAULT FALSE,
    download_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_uploaded_by (uploaded_by),
    INDEX idx_created_at (created_at),
    INDEX idx_expires_at (expires_at)
);

-- Voice messages table
CREATE TABLE IF NOT EXISTS voice_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    duration_seconds INT NOT NULL,
    waveform_data JSON NULL,
    transcript TEXT NULL,
    file_size BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    INDEX idx_message_id (message_id),
    INDEX idx_duration_seconds (duration_seconds)
);

-- Audit log table for tracking user actions
CREATE TABLE IF NOT EXISTS audit_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    target_user_id VARCHAR(50) NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cleanup old typing events (older than 30 seconds)
CREATE EVENT IF NOT EXISTS cleanup_typing_events
ON SCHEDULE EVERY 10 SECOND
DO
    DELETE FROM typing_events 
    WHERE last_seen_at < DATE_SUB(NOW(), INTERVAL 30 SECOND);

-- Update conversation last_message when new message is sent
CREATE TRIGGER IF NOT EXISTS update_conversation_last_message
    AFTER INSERT ON messages
    FOR EACH ROW
BEGIN
    UPDATE conversations 
    SET last_message_id = NEW.id, 
        last_message_at = NEW.created_at,
        updated_at = NEW.created_at
    WHERE id = NEW.conversation_id;
END;

-- Update conversation updated_at when message is edited
CREATE TRIGGER IF NOT EXISTS update_conversation_on_message_update
    AFTER UPDATE ON messages
    FOR EACH ROW
BEGIN
    UPDATE conversations 
    SET updated_at = NEW.updated_at
    WHERE id = NEW.conversation_id;
END;

-- Stored procedure to create employee with user account
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