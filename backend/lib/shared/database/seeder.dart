import 'dart:async';

class DatabaseSeeder {
  /// Ensures essential system data (Roles, Permissions, Default Admin) exists.
  static Future<void> seed(dynamic conn) async {
    try {
      print('[SEEDER] Ensuring system roles and default admin...');
      
      // 1. Seed Essential Roles
      final roles = [
        ['Admin', 'Accès complet à toutes les pages, gestion système, utilisateurs, rôles, finances, clients'],
        ['RH', 'Gestion des employés, salaires, congés, pointage, télétravail'],
        ['Manager', 'Gestion des projets, tâches, suivi équipes, clients, revenus, devis'],
        ['Team Lead', 'Gestion des tâches dans les projets, affectation des tâches, suivi technique'],
        ['Employé', 'Exécution des tâches, mise à jour de l\'avancement, communication interne, consultation des projets'],
        ['Comptable', 'Gestion des paiements, factures, devis, crédits, revenus, validation salaires'],
        ['Client', 'Consultation des devis, factures et statut de projet']
      ];
      
      for (var r in roles) {
        await conn.execute(
          "INSERT IGNORE INTO roles (nom, description) VALUES (:nom, :desc)", 
          {'nom': r[0], 'desc': r[1]}
        );
      }

      // 2. Check if ANY user exists. If not, seed the default admin.
      final userCheck = await conn.execute("SELECT COUNT(*) as cnt FROM users");
      final userCount = int.tryParse(userCheck.rows.first.colByName('cnt')?.toString() ?? '0') ?? 0;
      
      if (userCount == 0) {
        print('[SEEDER] Empty user table detected. Seeding default admin account...');
        
        final adminId = 'admin-uuid-001';
        
        await conn.execute('''
          INSERT IGNORE INTO users (id, username, password, role) 
          VALUES (:id, 'admin', '\$2a\$10\$VyhT7gdlBgt2HjqQ8ng.5OHqw3MxkZFXhu9AcOjyCTlKeNQovNKAu', 'Admin')
        ''', {'id': adminId});

        await conn.execute('''
          INSERT IGNORE INTO employees (id, user_id, matricule, nom, prenom, email, poste, departement, statut)
          VALUES (:id, :id, 'ADM-001', 'Admin', 'System', 'admin@fshub.com', 'System Administrator', 'IT', 'actif')
        ''', {'id': adminId});
        
        print('[SEEDER] SUCCESS: Default admin created (admin / @ForeverSoftware2026)');
      }

      // 3. Seed Permissions
      final perms = [
        ['manage_employees', 'HR', 'Gestion des employés'],
        ['view_employees', 'HR', 'Consultation des employés'],
        ['manage_salaries', 'HR', 'Gestion des salaires'],
        ['manage_leaves', 'HR', 'Gestion des congés'],
        ['manage_attendance', 'HR', 'Gestion du pointage'],
        ['manage_remote_work', 'HR', 'Gestion du télétravail'],
        ['manage_bonuses', 'HR', 'Gestion des bonus'],
        ['view_projects', 'Projects', 'Consultation des projets'],
        ['manage_projects', 'Projects', 'Gestion des projets'],
        ['view_tasks', 'Tasks', 'Consultation des tâches'],
        ['manage_tasks', 'Tasks', 'Gestion des tâches']
      ];

      for (var p in perms) {
        await conn.execute(
          "INSERT IGNORE INTO permissions (nom, module, description) VALUES (:nom, :mod, :desc)",
          {'nom': p[0], 'mod': p[1], 'desc': p[2]}
        );
      }

      // 4. Assign HR Permissions to RH (and Admin)
      print('[SEEDER] Linking permissions to roles...');
      
      // RH gets all HR module permissions
      await conn.execute('''
        INSERT IGNORE INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id FROM roles r, permissions p
        WHERE (r.nom = 'RH' OR r.nom = 'Admin') AND p.module = 'HR'
      ''');

      // Admin gets everything else too
      await conn.execute('''
        INSERT IGNORE INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id FROM roles r, permissions p
        WHERE r.nom = 'Admin'
      ''');
      
      print('[SEEDER] Seeding complete.');
    } catch (e) {
      print('[SEEDER] Warning: System seeding encountered an issue: $e');
    }
  }
}
