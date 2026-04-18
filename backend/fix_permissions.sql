-- Fix missing chat permissions and assignments
USE fs_hub_db;

-- 1. Ensure Communication module permissions exist
INSERT IGNORE INTO permissions (nom, module, description) VALUES
('send_messages', 'Communication', 'Envoi de messages'),
('view_messages', 'Communication', 'Consultation des messages'),
('manage_chat', 'Communication', 'Gestion du chat interne');

-- 2. Assign to Admin (all from Communication)
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Admin' AND p.module = 'Communication';

-- 3. Assign to Employé
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Employé' AND p.nom IN ('send_messages', 'view_messages');

-- 4. Assign to RH
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'RH' AND p.nom IN ('send_messages', 'view_messages');

-- 5. Assign to Manager
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Manager' AND p.nom IN ('send_messages', 'view_messages');

-- 6. Assign to Team Lead
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Team Lead' AND p.nom IN ('send_messages', 'view_messages', 'manage_chat');

-- 7. Add missing self-service permissions for Employé (just in case)
INSERT IGNORE INTO permissions (nom, module, description) VALUES
('view_own_salary', 'HR', 'Voir ses propres bulletins de paie'),
('view_own_bonuses', 'HR', 'Voir ses propres bonus et primes');

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.nom = 'Employé' AND p.nom IN ('view_own_salary', 'view_own_bonuses');
