import '../../../../shared/database/connection.dart';
import '../models/project_model.dart';

class ProjectRepository {
  final _db = DBConnection.getConnection();

  Future<List<ProjectModel>> getAllProjects() async {
    final result = await _db.execute('''
      SELECT p.*, c.nom as client_nom, c.prenom as client_prenom, c.raison_sociale as client_raison_sociale
      FROM projets p
      LEFT JOIN clients c ON p.client_id = c.id
      WHERE p.is_deleted = FALSE
      ORDER BY p.id DESC
    ''');

    return result.rows.map<ProjectModel>((row) => ProjectModel.fromMap(row.assoc())).toList();
  }

  /// Returns only projects associated with a client whose user_id matches [userId].
  Future<List<ProjectModel>> getProjectsByUserId(String userId) async {
    final result = await _db.execute('''
      SELECT p.*, c.nom as client_nom, c.prenom as client_prenom, c.raison_sociale as client_raison_sociale
      FROM projets p
      INNER JOIN clients c ON p.client_id = c.id
      WHERE c.user_id = :userId AND p.is_deleted = FALSE
      ORDER BY p.id DESC
    ''', {'userId': userId});

    return result.rows.map<ProjectModel>((row) => ProjectModel.fromMap(row.assoc())).toList();
  }

  /// Returns only projects where the employee is a member.
  Future<List<ProjectModel>> getProjectsByEmployeeId(String employeeId) async {
    final result = await _db.execute('''
      SELECT p.*, c.nom as client_nom, c.prenom as client_prenom, c.raison_sociale as client_raison_sociale
      FROM projets p
      INNER JOIN projet_membres pm ON p.id = pm.projet_id
      LEFT JOIN clients c ON p.client_id = c.id
      WHERE pm.employee_id = :employeeId AND p.is_deleted = FALSE
      ORDER BY p.id DESC
    ''', {'employeeId': employeeId});

    return result.rows.map<ProjectModel>((row) => ProjectModel.fromMap(row.assoc())).toList();
  }

  Future<ProjectModel?> getProjectById(int id) async {
    final result = await _db.execute('''
      SELECT p.*, c.nom as client_nom, c.prenom as client_prenom, c.raison_sociale as client_raison_sociale
      FROM projets p
      LEFT JOIN clients c ON p.client_id = c.id
      WHERE p.id = :id AND p.is_deleted = FALSE
    ''', {'id': id});

    if (result.rows.isEmpty) return null;
    return ProjectModel.fromMap(result.rows.first.assoc());
  }

  Future<int> createProject(Map<String, dynamic> data) async {
    final result = await _db.execute('''
      INSERT INTO projets (
        nom, description, client_id, budget, cout_estime, 
        date_debut, date_fin_prevue, priorite, statut
      ) VALUES (
        :nom, :description, :client_id, :budget, :cout_estime, 
        :date_debut, :date_fin_prevue, :priorite, :statut
      )
    ''', {
      'nom': data['nom'],
      'description': data['description'],
      'client_id': data['clientId'],
      'budget': data['budget'],
      'cout_estime': data['coutEstime'],
      'date_debut': data['dateDebut'],
      'date_fin_prevue': data['dateFinPrevue'],
      'priorite': data['priorite'],
      'statut': data['statut'],
    });

    final idRes = await _db.execute('SELECT LAST_INSERT_ID() as id');
    return int.tryParse(idRes.rows.first.colByName('id').toString()) ?? 0;
  }

  Future<void> updateProject(int id, Map<String, dynamic> data) async {
    await _db.execute('''
      UPDATE projets SET 
        nom = :nom, 
        description = :description, 
        client_id = :client_id, 
        budget = :budget, 
        cout_estime = :cout_estime, 
        date_debut = :date_debut, 
        date_fin_prevue = :date_fin_prevue, 
        priorite = :priorite, 
        statut = :statut
      WHERE id = :id
    ''', {
      'id': id,
      'nom': data['nom'],
      'description': data['description'],
      'client_id': data['clientId'],
      'budget': data['budget'],
      'cout_estime': data['coutEstime'],
      'date_debut': data['dateDebut'],
      'date_fin_prevue': data['dateFinPrevue'],
      'priorite': data['priorite'],
      'statut': data['statut'],
    });
  }

  Future<void> deleteProject(int id) async {
    await _db.execute('UPDATE projets SET is_deleted = TRUE WHERE id = :id', {'id': id});
  }

  Future<bool> hasActiveSprints(int id) async {
    final res = await _db.execute('SELECT id FROM sprints WHERE projet_id = :id LIMIT 1', {'id': id});
    return res.rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getAvailableEmployees() async {
    final result = await _db.execute('''
      SELECT e.* 
      FROM employees e
      WHERE e.id NOT IN (
        SELECT pm.employee_id 
        FROM projet_membres pm
        JOIN projets p ON pm.projet_id = p.id
        WHERE p.statut = 'En cours'
      )
      ORDER BY e.nom ASC
    ''');

    return result.rows.map((row) {
      final data = row.assoc();
      return {
        'id': data['id'],
        'employeeId': data['id'],
        'nom': data['nom'],
        'prenom': data['prenom'],
        'matricule': data['matricule'],
        'poste': data['poste'],
        'email': data['email'],
        'photo': data['photo'],
      };
    }).toList();
  }

  Future<List<ProjectMemberModel>> getProjectMembers(int projectId) async {
    final result = await _db.execute('''
      SELECT pm.id as membership_id, pm.role, pm.joined_at, 
             e.*, d.nom as dept_name
      FROM projet_membres pm
      JOIN employees e ON pm.employee_id = e.id
      LEFT JOIN departements d ON e.departement = d.id
      WHERE pm.projet_id = :id
    ''', {'id': projectId});

    return result.rows.map<ProjectMemberModel>((row) => ProjectMemberModel.fromMap(row.assoc())).toList();
  }

  Future<void> addProjectMember(int projectId, String employeeId, String role) async {
    await _db.execute('''
      INSERT INTO projet_membres (projet_id, employee_id, role)
      VALUES (:proj, :emp, :role)
    ''', {
      'proj': projectId,
      'emp': employeeId,
      'role': role,
    });
  }

  Future<void> removeProjectMember(int projectId, String employeeId) async {
    await _db.execute('''
      DELETE FROM projet_membres 
      WHERE projet_id = :proj AND employee_id = :emp
    ''', {
      'proj': projectId,
      'emp': employeeId,
    });
  }

  Future<bool> isMember(int projectId, String employeeId) async {
    final res = await _db.execute(
      'SELECT id FROM projet_membres WHERE projet_id = :proj AND employee_id = :emp LIMIT 1',
      {'proj': projectId, 'emp': employeeId}
    );
    return res.rows.isNotEmpty;
  }

  Future<bool> isClientOwner(int projectId, String userId) async {
    final res = await _db.execute('''
      SELECT p.id FROM projets p
      JOIN clients c ON p.client_id = c.id
      WHERE p.id = :proj AND c.user_id = :userId LIMIT 1
    ''', {'proj': projectId, 'userId': userId});
    return res.rows.isNotEmpty;
  }
}
