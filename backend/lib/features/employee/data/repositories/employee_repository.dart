import '../../../../shared/database/connection.dart';
import '../models/employee_model.dart';
import 'package:uuid/uuid.dart';

class EmployeeRepository {
  final _db = DBConnection.getConnection();

  Future<Map<String, dynamic>> getAllEmployees({int limit = 50, int offset = 0}) async {
    final countRes = await _db.execute('SELECT COUNT(*) as total FROM employees');
    final total = int.tryParse(countRes.rows.first.colByName('total')?.toString() ?? '0') ?? 0;

    final result = await _db.execute('''
      SELECT e.id, e.user_id, e.matricule, e.nom, e.prenom, e.dateNaissance,
             e.sexe, e.photo, e.email, e.telephone, e.adresse, e.ville,
             e.poste, e.departement, e.dateEmbauche, e.typeContrat, e.statut,
             e.created_at, e.updated_at,
             u.username, u.role
      FROM employees e
      LEFT JOIN users u ON e.user_id = u.id
      ORDER BY e.created_at DESC
      LIMIT $limit OFFSET $offset
    ''');

    final employees = result.rows.map<EmployeeModel>((row) => EmployeeModel.fromMap({
      'id': row.colByName('id'),
      'user_id': row.colByName('user_id'),
      'matricule': row.colByName('matricule'),
      'nom': row.colByName('nom'),
      'prenom': row.colByName('prenom'),
      'dateNaissance': row.colByName('dateNaissance'),
      'sexe': row.colByName('sexe'),
      'photo': row.colByName('photo'),
      'email': row.colByName('email'),
      'telephone': row.colByName('telephone'),
      'adresse': row.colByName('adresse'),
      'ville': row.colByName('ville'),
      'poste': row.colByName('poste'),
      'departement': row.colByName('departement'),
      'dateEmbauche': row.colByName('dateEmbauche'),
      'typeContrat': row.colByName('typeContrat'),
      'statut': row.colByName('statut'),
      'created_at': row.colByName('created_at'),
      'updated_at': row.colByName('updated_at'),
      'username': row.colByName('username'),
      'role': row.colByName('role'),
    })).toList();

    return {
      'total': total,
      'employees': employees,
    };
  }

  Future<EmployeeModel?> getEmployeeById(String id) async {
    final result = await _db.execute('''
      SELECT e.id, e.user_id, e.matricule, e.nom, e.prenom, e.dateNaissance,
             e.sexe, e.photo, e.email, e.telephone, e.adresse, e.ville,
             e.poste, e.departement, e.dateEmbauche, e.typeContrat, e.statut,
             e.created_at, e.updated_at,
             u.username, u.role
      FROM employees e
      LEFT JOIN users u ON e.user_id = u.id
      WHERE e.id = :id
    ''', {'id': id});

    if (result.rows.isEmpty) return null;

    final row = result.rows.first;
    return EmployeeModel.fromMap({
      'id': row.colByName('id'),
      'user_id': row.colByName('user_id'),
      'matricule': row.colByName('matricule'),
      'nom': row.colByName('nom'),
      'prenom': row.colByName('prenom'),
      'dateNaissance': row.colByName('dateNaissance'),
      'sexe': row.colByName('sexe'),
      'photo': row.colByName('photo'),
      'email': row.colByName('email'),
      'telephone': row.colByName('telephone'),
      'adresse': row.colByName('adresse'),
      'ville': row.colByName('ville'),
      'poste': row.colByName('poste'),
      'departement': row.colByName('departement'),
      'dateEmbauche': row.colByName('dateEmbauche'),
      'typeContrat': row.colByName('typeContrat'),
      'statut': row.colByName('statut'),
      'created_at': row.colByName('created_at'),
      'updated_at': row.colByName('updated_at'),
      'username': row.colByName('username'),
      'role': row.colByName('role'),
    });
  }

  Future<String> createEmployee(Map<String, dynamic> data) async {
    return await _db.transaction((tx) async {
       // Check username uniqueness
      final existingUser = await tx.execute(
        'SELECT id FROM users WHERE username = :username',
        {'username': data['username']},
      );
      if (existingUser.rows.isNotEmpty) throw Exception('Username already exists');

      final userId = const Uuid().v4();
      
      await tx.execute('''
        INSERT INTO users (id, username, password, role, created_at)
        VALUES (:id, :username, :password, :role, NOW())
      ''', {
        'id': userId,
        'username': data['username'],
        'password': data['hashedPassword'],
        'role': data['role'] ?? 'Employé',
      });

      // RBAC: Link user to role in user_roles table
      final roleName = data['role'] ?? 'Employé';
      final roleResult = await tx.execute(
        'SELECT id FROM roles WHERE nom = :role',
        {'role': roleName},
      );
      
      if (roleResult.rows.isNotEmpty) {
        final roleId = roleResult.rows.first.colAt(0);
        await tx.execute('''
          INSERT INTO user_roles (user_id, role_id, assigned_at)
          VALUES (:userId, :roleId, NOW())
        ''', {
          'userId': userId,
          'roleId': roleId,
        });
      }

      // Find departement_id
      int? deptId;
      if (data['departement'] != null && data['departement'].toString().trim().isNotEmpty) {
        final dRes = await tx.execute('SELECT id FROM departements WHERE nom = :nom', {'nom': data['departement']});
        if (dRes.rows.isNotEmpty) deptId = int.tryParse(dRes.rows.first.colAt(0).toString());
      }

      // Find poste_id
      int? posteId;
      if (data['poste'] != null && data['poste'].toString().trim().isNotEmpty) {
        final pRes = await tx.execute('SELECT id FROM postes WHERE nom = :nom', {'nom': data['poste']});
        if (pRes.rows.isNotEmpty) posteId = int.tryParse(pRes.rows.first.colAt(0).toString());
      }

      await tx.execute('''
        INSERT INTO employees (id, user_id, matricule, nom, prenom, dateNaissance,
                               sexe, photo, email, telephone, adresse, ville,
                               poste, departement, poste_id, departement_id, 
                               dateEmbauche, typeContrat, statut)
        VALUES (:id, :user_id, :matricule, :nom, :prenom, :dateNaissance,
                :sexe, :photo, :email, :telephone, :adresse, :ville,
                :poste, :departement, :poste_id, :departement_id,
                :dateEmbauche, :typeContrat, :statut)
      ''', {
        'id': userId,
        'user_id': userId,
        'matricule': data['matricule'],
        'nom': data['nom'],
        'prenom': data['prenom'],
        'dateNaissance': data['dateNaissance'],
        'sexe': data['sexe'],
        'photo': data['photo'],
        'email': data['email'],
        'telephone': data['telephone'],
        'adresse': data['adresse'],
        'ville': data['ville'],
        'poste': data['poste'],
        'departement': data['departement'],
        'poste_id': posteId,
        'departement_id': deptId,
        'dateEmbauche': data['dateEmbauche'],
        'typeContrat': data['typeContrat'],
        'statut': data['statut'] ?? 'actif',
      });

      return userId;
    });
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    await _db.transaction((tx) async {
      int? deptId;
      if (data['departement'] != null && data['departement'].toString().trim().isNotEmpty) {
        final dRes = await tx.execute('SELECT id FROM departements WHERE nom = :nom', {'nom': data['departement']});
        if (dRes.rows.isNotEmpty) deptId = int.tryParse(dRes.rows.first.colAt(0).toString());
      }

      int? posteId;
      if (data['poste'] != null && data['poste'].toString().trim().isNotEmpty) {
        final pRes = await tx.execute('SELECT id FROM postes WHERE nom = :nom', {'nom': data['poste']});
        if (pRes.rows.isNotEmpty) posteId = int.tryParse(pRes.rows.first.colAt(0).toString());
      }

      await tx.execute('''
        UPDATE employees
        SET matricule = :matricule, nom = :nom, prenom = :prenom,
            dateNaissance = :dateNaissance, sexe = :sexe,
            photo = :photo, email = :email, telephone = :telephone,
            adresse = :adresse, ville = :ville, poste = :poste,
            departement = :departement, poste_id = :poste_id, departement_id = :departement_id,
            dateEmbauche = :dateEmbauche, typeContrat = :typeContrat, statut = :statut, updated_at = NOW()
        WHERE id = :id
      ''', {
        'matricule': data['matricule'],
        'nom': data['nom'],
        'prenom': data['prenom'],
        'dateNaissance': data['dateNaissance'],
        'sexe': data['sexe'],
        'photo': data['photo'],
        'email': data['email'],
        'telephone': data['telephone'],
        'adresse': data['adresse'],
        'ville': data['ville'],
        'poste': data['poste'],
        'departement': data['departement'],
        'poste_id': posteId,
        'departement_id': deptId,
        'dateEmbauche': data['dateEmbauche'],
        'typeContrat': data['typeContrat'],
        'statut': data['statut'],
        'id': id,
      });
    });
  }

  Future<void> deactivateEmployee(String id, String? userId) async {
    await _db.transaction((tx) async {
      await tx.execute("UPDATE employees SET statut = 'inactif', updated_at = NOW() WHERE id = :id", {'id': id});
      if (userId != null) {
        await tx.execute("UPDATE users SET is_active = 0 WHERE id = :userId", {'userId': userId});
        await tx.execute("UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = :userId", {'userId': userId});
      }
    });
  }
}
