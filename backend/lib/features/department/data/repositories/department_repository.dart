import '../../../../shared/database/connection.dart';
import '../models/department_model.dart';

class DepartmentRepository {
  final _db = DBConnection.getConnection();

  Future<List<DepartmentModel>> getAllDepartments() async {
    final result = await _db.execute('''
      SELECT id, nom, budget_annuel, created_at, updated_at
      FROM departements
      ORDER BY nom ASC
    ''');

    return result.rows.map<DepartmentModel>((row) => DepartmentModel.fromMap(row.assoc())).toList();
  }

  Future<DepartmentModel?> getDepartmentById(String id) async {
    final result = await _db.execute('''
      SELECT id, nom, budget_annuel, created_at, updated_at
      FROM departements
      WHERE id = :id
    ''', {'id': id});

    if (result.rows.isEmpty) return null;
    return DepartmentModel.fromMap(result.rows.first.assoc());
  }

  Future<void> createDepartment(Map<String, dynamic> data) async {
    await _db.execute('''
      INSERT INTO departements (nom, budget_annuel)
      VALUES (:nom, :budget_annuel)
    ''', {
      'nom': data['nom'],
      'budget_annuel': data['budgetAnnuel'] ?? 0.0,
    });
  }

  Future<void> updateDepartment(String id, Map<String, dynamic> data) async {
    await _db.execute('''
      UPDATE departements 
      SET nom = :nom, budget_annuel = :budget_annuel, updated_at = NOW()
      WHERE id = :id
    ''', {
      'nom': data['nom'],
      'budget_annuel': data['budgetAnnuel'] ?? 0.0,
      'id': id,
    });
  }

  Future<void> deleteDepartment(String id) async {
    await _db.execute('DELETE FROM departements WHERE id = :id', {'id': id});
  }

  Future<int> getEmployeeCount(String departmentId) async {
    final res = await _db.execute('SELECT COUNT(*) as cnt FROM employees WHERE departement = :id', {'id': departmentId});
    return int.tryParse(res.rows.first.colByName('cnt').toString()) ?? 0;
  }
}
