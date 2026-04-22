import '../models/poste_model.dart';
import '../../../../shared/database/connection.dart';

class PosteRepository {
  final _db = DBConnection.getConnection();

  Future<List<PosteModel>> getAllPostes() async {
    try {
      final results = await _db.execute('SELECT id, nom, description, departement_id, created_at FROM postes ORDER BY nom');
      return results.rows.map<PosteModel>((row) => PosteModel.fromJson(row.assoc())).toList();
    } catch (e) {
      print('Error in getAllPostes: $e');
      return [];
    }
  }

  Future<PosteModel?> getPosteById(int id) async {
    try {
      final results = await _db.execute('SELECT * FROM postes WHERE id = :id', {'id': id});
      
      if (results.rows.isEmpty) return null;
      return PosteModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      print('Error in getPosteById: $e');
      return null;
    }
  }

  Future<PosteModel> createPoste(PosteModel poste) async {
    try {
      final results = await _db.execute('''
        INSERT INTO postes (nom, description, departement_id)
        VALUES (:nom, :description, :deptId)
      ''', {
        'nom': poste.nom,
        'description': poste.description,
        'deptId': poste.departementId,
      });
      
      final id = results.lastInsertID.toInt();
      return poste.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create poste: $e');
    }
  }


  Future<PosteModel> updatePoste(PosteModel poste) async {
    try {
      await _db.execute('''
        UPDATE postes 
        SET nom = :nom, description = :description, departement_id = :deptId, updated_at = CURRENT_TIMESTAMP
        WHERE id = :id
      ''', {
        'nom': poste.nom,
        'description': poste.description,
        'deptId': poste.departementId,
        'id': poste.id,
      });
      
      return poste;
    } catch (e) {
      throw Exception('Failed to update poste: $e');
    }
  }


  Future<bool> deletePoste(int id) async {
    try {
      final results = await _db.execute('DELETE FROM postes WHERE id = :id', {'id': id});
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<PosteModel?> getPosteByName(String name) async {
    try {
      final results = await _db.execute('SELECT id, nom, description, departement_id, created_at FROM postes WHERE nom = :name', {'name': name});
      
      if (results.rows.isEmpty) return null;
      return PosteModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      print('Error in getPosteByName: $e');
      return null;
    }
  }

  Future<List<PosteModel>> getPostesByDepartment(int departmentId) async {
    try {
      final results = await _db.execute(
        'SELECT id, nom, description, departement_id, created_at FROM postes WHERE departement_id = :deptId ORDER BY nom',
        {'deptId': departmentId},
      );
      return results.rows.map<PosteModel>((row) => PosteModel.fromJson(row.assoc())).toList();
    } catch (e) {
      print('Error in getPostesByDepartment: $e');
      rethrow;
    }
  }

  Future<List<PosteModel>> searchPostes(String query) async {
    try {
      final results = await _db.execute('''
        SELECT * FROM postes 
        WHERE nom LIKE :query OR description LIKE :query
        ORDER BY nom
      ''', {'query': '%$query%'});
      
      return results.rows.map<PosteModel>((row) => PosteModel.fromJson(row.assoc())).toList();
    } catch (e) {
      print('Error in searchPostes: $e');
      return [];
    }
  }

  Future<int> getPosteCount() async {
    try {
      final results = await _db.execute('SELECT COUNT(*) as count FROM postes');
      
      if (results.rows.isEmpty) return 0;
      return int.tryParse(results.rows.first.colByName('count')?.toString() ?? '0') ?? 0;
    } catch (e) {
      print('Error in getPosteCount: $e');
      return 0;
    }
  }
}



