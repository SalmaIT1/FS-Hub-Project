-- Migration: Create roles and permissions system
-- This should be run on existing databases to add the roles and permissions tables

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
('manage_attendance', 'HR', 'Gestion du pointage'),
('manage_remote_work', 'HR', 'Gestion du télétravail'),
('manage_bonuses', 'HR', 'Gestion des primes et bonus'),

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
('assign_sprint_tasks', 'Tasks', 'Affectation des tâches dans un sprint'),

-- Project expenses permissions
('manage_project_expenses', 'Finance', 'Gestion des dépenses des projets'),
('view_project_expenses', 'Finance', 'Consultation des dépenses des projets'),

-- Company expenses permissions
('manage_company_expenses', 'Finance', 'Gestion des dépenses de la société'),
('view_company_expenses', 'Finance', 'Consultation des dépenses de la société');

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
WHERE r.nom = 'Manager' AND p.nom IN ('view_revenue', 'manage_quotes', 'view_project_expenses');

-- Additional specific permissions for Comptable  
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Comptable' AND p.nom IN ('view_revenue', 'manage_quotes', 'manage_project_expenses', 'manage_company_expenses');
