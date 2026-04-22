import '../models/role_permission_model.dart';
import '../../../../shared/database/connection.dart';

class RolePermissionRepository {
  final _db = DBConnection.getConnection();

  Future<List<RoleModel>> getAllRoles() async {
    try {
      final results = await _db.execute('SELECT * FROM roles ORDER BY nom');
      print('DEBUG: getAllRoles query returned ${results.rows.length} rows.');
      return results.rows.map<RoleModel>((row) => RoleModel.fromJson(row.assoc())).toList();
    } catch (e) {
      print('DEBUG: getAllRoles query ERRORED: $e');
      rethrow;
    }
  }

  Future<RoleModel?> getRoleById(int id) async {
    try {
      final results = await _db.execute('SELECT * FROM roles WHERE id = :id', {'id': id});
      
      if (results.rows.isEmpty) return null;
      return RoleModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }

  Future<RoleModel?> getRoleByName(String name) async {
    try {
      final results = await _db.execute('SELECT * FROM roles WHERE nom = :name', {'name': name});
      
      if (results.rows.isEmpty) return null;
      return RoleModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }

  Future<RoleModel> createRole(RoleModel role) async {
    try {
      final results = await _db.execute('''
        INSERT INTO roles (nom, description)
        VALUES (:nom, :description)
      ''', {
        'nom': role.nom,
        'description': role.description,
      });
      
      final id = results.lastInsertID.toInt();
      return role.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create role: $e');
    }
  }

  Future<RoleModel> updateRole(RoleModel role) async {
    try {
      await _db.execute('''
        UPDATE roles 
        SET nom = :nom, description = :description, updated_at = CURRENT_TIMESTAMP
        WHERE id = :id
      ''', {
        'nom': role.nom,
        'description': role.description,
        'id': role.id,
      });
      
      return role;
    } catch (e) {
      throw Exception('Failed to update role: $e');
    }
  }

  Future<bool> deleteRole(int id) async {
    try {
      final results = await _db.execute('DELETE FROM roles WHERE id = :id', {'id': id});
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<PermissionModel>> getAllPermissions() async {
    try {
      final results = await _db.execute('SELECT * FROM permissions ORDER BY nom');
      return results.rows.map<PermissionModel>((row) => PermissionModel.fromJson(row.assoc())).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<PermissionModel?> getPermissionById(int id) async {
    try {
      final results = await _db.execute('SELECT * FROM permissions WHERE id = :id', {'id': id});
      
      if (results.rows.isEmpty) return null;
      return PermissionModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }

  Future<PermissionModel> createPermission(PermissionModel permission) async {
    try {
      final results = await _db.execute('''
        INSERT INTO permissions (nom, description)
        VALUES (:nom, :description)
      ''', {
        'nom': permission.nom,
        'description': permission.description,
      });
      
      final id = results.lastInsertID.toInt();
      return permission.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create permission: $e');
    }
  }

  Future<PermissionModel> updatePermission(PermissionModel permission) async {
    try {
      await _db.execute('''
        UPDATE permissions 
        SET nom = :nom, description = :description, updated_at = CURRENT_TIMESTAMP
        WHERE id = :id
      ''', {
        'nom': permission.nom,
        'description': permission.description,
        'id': permission.id,
      });
      
      return permission;
    } catch (e) {
      throw Exception('Failed to update permission: $e');
    }
  }

  Future<List<PermissionModel>> getPermissionsByRole(int roleId) async {
    try {
      final results = await _db.execute('''
        SELECT p.* FROM permissions p
        INNER JOIN role_permissions rp ON p.id = rp.permission_id
        WHERE rp.role_id = :roleId
        ORDER BY p.nom
      ''', {'roleId': roleId});
      
      return results.rows.map<PermissionModel>((row) => PermissionModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> assignPermissionsToRole(int roleId, List<int> permissionIds) async {
    try {
      // First remove existing permissions
      await _db.execute('DELETE FROM role_permissions WHERE role_id = :roleId', {'roleId': roleId});
      
      // Then assign new permissions
      for (final permissionId in permissionIds) {
        await _db.execute('''
          INSERT INTO role_permissions (role_id, permission_id)
          VALUES (:roleId, :permissionId)
        ''', {
          'roleId': roleId,
          'permissionId': permissionId,
        });
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<PermissionModel>> getRolePermissions(int roleId) async {
    try {
      final results = await _db.execute('''
        SELECT p.* FROM permissions p
        INNER JOIN role_permissions rp ON p.id = rp.permission_id
        WHERE rp.role_id = :roleId
        ORDER BY p.nom
      ''', {'roleId': roleId});
      
      return results.rows.map<PermissionModel>((row) => PermissionModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> assignPermissionToRole(int roleId, int permissionId) async {
    try {
      await _db.execute('''
        INSERT INTO role_permissions (role_id, permission_id)
        VALUES (:roleId, :permissionId)
      ''', {
        'roleId': roleId,
        'permissionId': permissionId,
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removePermissionFromRole(int roleId, int permissionId) async {
    try {
      final results = await _db.execute('''
        DELETE FROM role_permissions 
        WHERE role_id = :roleId AND permission_id = :permissionId
      ''', {
        'roleId': roleId,
        'permissionId': permissionId,
      });
      
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<RoleModel>> getUserRoles(int userId) async {
    try {
      final results = await _db.execute('''
        SELECT r.* FROM roles r
        INNER JOIN user_roles ur ON r.id = ur.role_id
        WHERE ur.user_id = :userId
        ORDER BY r.nom
      ''', {'userId': userId});
      
      return results.rows.map<RoleModel>((row) => RoleModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> assignRoleToUser(int userId, int roleId) async {
    try {
      await _db.execute('''
        INSERT INTO user_roles (user_id, role_id)
        VALUES (:userId, :roleId)
      ''', {
        'userId': userId,
        'roleId': roleId,
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeRoleFromUser(int userId, int roleId) async {
    try {
      final results = await _db.execute('''
        DELETE FROM user_roles 
        WHERE user_id = :userId AND role_id = :roleId
      ''', {
        'userId': userId,
        'roleId': roleId,
      });
      
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deletePermission(int id) async {
    try {
      final results = await _db.execute('DELETE FROM permissions WHERE id = :id', {'id': id});
      return results.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<PermissionModel?> getPermissionByName(String name) async {
    try {
      final results = await _db.execute('SELECT * FROM permissions WHERE nom = :name', {'name': name});
      
      if (results.rows.isEmpty) return null;
      return PermissionModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }

  Future<List<PermissionModel>> getUserPermissions(int userId) async {
    try {
      final results = await _db.execute('''
        SELECT DISTINCT p.* FROM permissions p
        INNER JOIN role_permissions rp ON p.id = rp.permission_id
        INNER JOIN user_roles ur ON rp.role_id = ur.role_id
        WHERE ur.user_id = :userId
        ORDER BY p.nom
      ''', {'userId': userId});
      
      return results.rows.map<PermissionModel>((row) => PermissionModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PermissionModel>> getPermissionsByModule(String module) async {
    try {
      final results = await _db.execute('''
        SELECT p.* FROM permissions p
        WHERE p.module = :module
        ORDER BY p.nom
      ''', {'module': module});
      
      return results.rows.map<PermissionModel>((row) => PermissionModel.fromJson(row.assoc())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<RoleModel?> getUserRole(int userId) async {
    try {
      final results = await _db.execute('''
        SELECT r.* FROM roles r
        INNER JOIN user_roles ur ON r.id = ur.role_id
        INNER JOIN users u ON ur.user_id = u.id
        WHERE u.id = :userId
      ''', {'userId': userId});
      
      if (results.rows.isEmpty) return null;
      return RoleModel.fromJson(results.rows.first.assoc());
    } catch (e) {
      return null;
    }
  }
}




