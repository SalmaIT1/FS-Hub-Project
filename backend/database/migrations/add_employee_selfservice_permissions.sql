-- Migration: Add employee self-service permissions
-- Fixes: Employees could not access /hr/salaries and /hr/bonuses because
-- 'view_own_salary' and 'view_own_bonuses' were never inserted into the permissions table.

-- Step 1: Insert missing permissions (safe to re-run)
INSERT IGNORE INTO permissions (nom, module, description) VALUES
('view_own_salary',    'HR', 'Consultation de son propre bulletin de salaire'),
('view_own_bonuses',   'HR', 'Consultation de ses propres primes et bonus'),
('attendance.view',    'HR', 'Consultation de son historique de présence'),
('log_own_attendance', 'HR', 'Enregistrement de sa propre présence'),
('submit_leave',       'HR', 'Soumission d''une demande de congé'),
('submit_remote_work', 'HR', 'Soumission d''une demande de télétravail'),
('leave.request',      'HR', 'Demande de congé (dot-notation alias)');

-- Step 2: Assign all of them to the Employé role (safe to re-run)
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.nom = 'Employé'
  AND p.nom IN (
    'view_own_salary',
    'view_own_bonuses',
    'attendance.view',
    'log_own_attendance',
    'submit_leave',
    'submit_remote_work',
    'leave.request',
    'view_tasks',
    'execute_tasks',
    'update_task_progress',
    'send_messages',
    'view_messages',
    'view_projects'
  );

-- Verify result
SELECT r.nom AS role, p.nom AS permission
FROM roles r
JOIN role_permissions rp ON rp.role_id = r.id
JOIN permissions p ON p.id = rp.permission_id
WHERE r.nom = 'Employé'
ORDER BY p.module, p.nom;
