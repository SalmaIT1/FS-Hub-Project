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
    last_seen DATETIME NULL,
    profile_visible BOOLEAN DEFAULT TRUE,
    show_online_status BOOLEAN DEFAULT TRUE,
    analytics_enabled BOOLEAN DEFAULT FALSE
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
    is_active BOOLEAN DEFAULT TRUE,
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

CREATE TABLE IF NOT EXISTS postes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default positions
INSERT IGNORE INTO postes (nom, description) VALUES
('Directeur', 'Responsable de la direction générale et de la stratégie de l''entreprise'),
('Manager de projet', 'Gère les projets et coordonne les équipes de développement'),
('Team Lead', 'Encadre une équipe technique et assure la qualité des livrables'),
('Développeur', 'Développe des applications et des fonctionnalités techniques'),
('Designer', 'Crée les interfaces utilisateur et l''expérience visuelle'),
('Responsable RH', 'Gère les ressources humaines et les relations employés'),
('Comptable', 'Gère la comptabilité et les finances de l''entreprise'),
('Support technique', 'Assiste les utilisateurs et résout les problèmes techniques');

-- Roles and Permissions System
CREATE TABLE IF NOT EXISTS roles (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nom VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS permissions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nom VARCHAR(100),
    module VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id INT,
    permission_id INT,
    PRIMARY KEY (role_id, permission_id),
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
);

-- Insert specific roles
INSERT IGNORE INTO roles (nom, description) VALUES
('Admin', 'Accès complet à toutes les pages, gestion système, utilisateurs, rôles, finances, clients'),
('RH', 'Gestion des employés, salaires, congés, pointage, télétravail'),
('Manager', 'Gestion des projets, tâches, suivi équipes, clients, revenus, devis'),
('Team Lead', 'Gestion des tâches dans les projets, affectation des tâches, suivi technique'),
('Employé', 'Exécution des tâches, mise à jour de l''avancement, communication interne, consultation des projets'),
('Comptable', 'Gestion des paiements, factures, devis, crédits, revenus, validation salaires'),
('Client', 'Consultation des devis, factures et statut de projet');

-- Insert comprehensive permissions
INSERT IGNORE INTO permissions (nom, module, description) VALUES
-- System permissions
('manage_system', 'System', 'Gestion globale du système'),
('manage_users', 'Users', 'Gestion des utilisateurs'),
('manage_roles', 'Users', 'Gestion des rôles et permissions'),
('view_statistics', 'System', 'Accès aux statistiques et rapports'),

-- HR permissions
('manage_employees', 'HR', 'Gestion complète des employés'),
('view_employees', 'HR', 'Consultation des employés'),
('manage_salaries', 'HR', 'Gestion des salaires'),
('manage_leaves', 'HR', 'Gestion des congés'),
('manage_attendance', 'HR', 'Gestion du pointage par un manager ou RH'),
('log_own_attendance', 'HR', 'Enregistrer sa propre présence / check-in check-out'),
('manage_remote_work', 'HR', 'Gestion du télétravail par un manager ou RH'),
('submit_remote_work', 'HR', 'Soumettre une demande de télétravail'),
('manage_bonuses', 'HR', 'Gestion des bonus et récompenses'),
('submit_leave', 'HR', 'Soumettre une demande de congé'),

-- Project permissions
('manage_projects', 'Projects', 'Gestion complète des projets'),
('view_projects', 'Projects', 'Consultation des projets'),
('manage_project_teams', 'Projects', 'Gestion des équipes de projet'),
('view_team_performance', 'Projects', 'Suivi des performances d''équipe'),

-- Task permissions
('manage_tasks', 'Tasks', 'Gestion complète des tâches'),
('view_tasks', 'Tasks', 'Consultation des tâches'),
('assign_tasks', 'Tasks', 'Affectation des tâches'),
('update_task_progress', 'Tasks', 'Mise à jour de l''avancement des tâches'),
('execute_tasks', 'Tasks', 'Exécution des tâches'),

-- Communication permissions
('send_messages', 'Communication', 'Envoi de messages'),
('view_messages', 'Communication', 'Consultation des messages'),
('manage_chat', 'Communication', 'Gestion du chat interne'),

-- Financial permissions
('manage_payments', 'Finance', 'Gestion des paiements'),
('manage_invoices', 'Finance', 'Gestion des factures'),
('manage_quotes', 'Finance', 'Gestion des devis'),
('manage_credits', 'Finance', 'Gestion des crédits'),
('view_financial_reports', 'Finance', 'Consultation des rapports financiers'),

-- Client permissions
('view_quotes', 'Client', 'Consultation des devis'),
('view_invoices', 'Client', 'Consultation des factures'),
('view_project_status', 'Client', 'Consultation du statut des projets'),

-- Client management permissions
('manage_clients', 'Clients', 'Gestion complète des clients'),
('view_clients', 'Clients', 'Consultation des clients'),

-- Revenue tracking permissions
('view_revenue', 'Finance', 'Suivi des revenus de la société'),
('manage_revenue', 'Finance', 'Gestion des revenus'),

-- Notification management permissions
('manage_notifications', 'System', 'Gestion des notifications'),
('view_notifications', 'System', 'Consultation des notifications'),

-- Sprint management permissions
('manage_sprints', 'Projects', 'Gestion des sprints'),
('assign_sprint_tasks', 'Tasks', 'Affectation des tâches dans un sprint');

-- Assign permissions to Admin (all permissions)
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Admin';

-- Assign permissions to RH
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'RH' AND p.module IN ('HR', 'Users');

-- Assign permissions to Manager
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Manager' AND p.module IN ('Projects', 'Tasks', 'Clients', 'Finance');

-- Assign permissions to Team Lead
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Team Lead' AND p.module IN ('Tasks', 'Projects', 'Communication');

-- Assign permissions to Employé
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Employé' AND p.nom IN ('view_tasks', 'update_task_progress', 'execute_tasks', 'send_messages', 'view_messages', 'view_projects');

-- Assign permissions to Comptable
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Comptable' AND (
  p.module IN ('Finance', 'System') OR 
  p.nom IN ('view_revenue', 'manage_revenue')
);

-- Assign permissions to Client
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Client' AND p.module IN ('Client');

-- Additional specific permissions for Manager
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Manager' AND p.nom IN ('view_revenue', 'manage_quotes');

-- Additional specific permissions for Comptable  
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Comptable' AND p.nom IN ('view_revenue', 'manage_quotes');

-- HR MODULE TABLES
CREATE TABLE IF NOT EXISTS attendance (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id VARCHAR(50) NOT NULL,
    attendance_date DATE NOT NULL,
    check_in DATETIME,
    check_out DATETIME,
    status ENUM('present', 'late', 'absent', 'half_day', 'remote', 'leave') DEFAULT 'present',
    work_hours DECIMAL(5,2),
    overtime_hours DECIMAL(5,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    UNIQUE(employee_id, attendance_date)
);

CREATE TABLE IF NOT EXISTS leave_requests (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id VARCHAR(50) NOT NULL,
    leave_type ENUM('paid_leave', 'sick_leave', 'unpaid_leave', 'maternity_leave', 'emergency_leave'),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_days INT,
    status ENUM('pending', 'approved', 'rejected', 'cancelled') DEFAULT 'pending',
    reason TEXT,
    approved_by VARCHAR(50),
    approved_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    FOREIGN KEY (approved_by) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS remote_work (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id VARCHAR(50) NOT NULL,
    remote_date DATE NOT NULL,
    type ENUM('full_day', 'half_day', 'emergency') DEFAULT 'full_day',
    reason TEXT,
    approved_by VARCHAR(50),
    status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    FOREIGN KEY (approved_by) REFERENCES users(id),
    UNIQUE(employee_id, remote_date)
);

CREATE TABLE IF NOT EXISTS salaries (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id VARCHAR(50) NOT NULL,
    base_salary DECIMAL(12,2) NOT NULL,
    bonus_amount DECIMAL(12,2) DEFAULT 0,
    deductions DECIMAL(12,2) DEFAULT 0,
    net_salary DECIMAL(12,2),
    salary_month DATE NOT NULL,
    payment_status ENUM('pending', 'paid', 'cancelled') DEFAULT 'pending',
    paid_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    UNIQUE(employee_id, salary_month)
);

CREATE TABLE IF NOT EXISTS bonuses (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id VARCHAR(50) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    reason VARCHAR(255),
    bonus_type ENUM('performance', 'project_completion', 'holiday', 'referral', 'other') DEFAULT 'performance',
    granted_by VARCHAR(50),
    granted_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    FOREIGN KEY (granted_by) REFERENCES users(id)
);

-- Recommended Indexes
CREATE INDEX idx_attendance_employee ON attendance(employee_id);
CREATE INDEX idx_leave_employee ON leave_requests(employee_id);
CREATE INDEX idx_remote_employee ON remote_work(employee_id);
CREATE INDEX idx_salary_employee ON salaries(employee_id);
CREATE INDEX idx_bonus_employee ON bonuses(employee_id);

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Admin' AND p.nom = 'manage_bonuses';

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'RH' AND p.nom = 'manage_bonuses';

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Comptable' AND p.nom IN ('manage_salaries', 'manage_bonuses');

INSERT IGNORE INTO employees (id, user_id, matricule, nom, prenom, email, poste, departement, statut)
VALUES ('admin-uuid-001', 'admin-uuid-001', 'ADM-001', 'Admin', 'System', 'admin@fshub.com', 'System Administrator', 'IT', 'actif');
