import '../../data/models/role_permission_model.dart';
import '../../data/repositories/role_permission_repository.dart';
import '../../../../core/middleware/auth_middleware.dart';

void _invalidateUsersForRole(RolePermissionRepository repo, int roleId) {
  repo.getUserIdsAffectedByRole(roleId).then((ids) {
    for (final id in ids) {
      invalidatePermissionCache(id);
    }
  });
}

class RoleService {
  final RolePermissionRepository _repository = RolePermissionRepository();

  Future<List<RoleModel>> getAllRoles() {
    return _repository.getAllRoles();
  }

  Future<RoleModel?> getRoleById(int id) {
    return _repository.getRoleById(id);
  }

  Future<RoleModel?> getRoleByName(String name) {
    return _repository.getRoleByName(name);
  }

  Future<RoleModel> createRole(RoleModel role) {
    return _repository.createRole(role);
  }

  Future<RoleModel> updateRole(RoleModel role) {
    return _repository.updateRole(role);
  }

  Future<bool> deleteRole(int id) {
    return _repository.deleteRole(id);
  }

  Future<List<Map<String, dynamic>>> getRolesWithPermissions() async {
    final roles = await getAllRoles();
    final rolesWithPermissions = <Map<String, dynamic>>[];
    
    for (final role in roles) {
      final permissions = await _repository.getPermissionsByRole(role.id!);
      rolesWithPermissions.add({
        'id': role.id,
        'nom': role.nom,
        'description': role.description,
        'permissions': permissions.map((p) => p.toJson()).toList(),
      });
    }
    
    return rolesWithPermissions;
  }

  Future<Map<String, dynamic>> createRoleFromJson(Map<String, dynamic> json) async {
    try {
      final role = RoleModel(
        nom: json['nom'],
        description: json['description'],
      );

      final createdRole = await createRole(role);
      
      // Assign permissions if provided
      if (json['permission_ids'] != null && json['permission_ids'] is List) {
        final permissionIds = (json['permission_ids'] as List)
            .map((id) => int.parse(id.toString()))
            .toList();
        
        await _repository.assignPermissionsToRole(createdRole.id!, permissionIds);
        _invalidateUsersForRole(_repository, createdRole.id!);
      }
      
      return {
        'success': true,
        'message': 'Role created successfully',
        'data': createdRole.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create role: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> updateRoleFromJson(int id, Map<String, dynamic> json) async {
    try {
      final role = RoleModel(
        id: id,
        nom: json['nom'],
        description: json['description'],
      );

      final updatedRole = await updateRole(role);
      
      // Update permissions if provided
      if (json['permission_ids'] != null && json['permission_ids'] is List) {
        final permissionIds = (json['permission_ids'] as List)
            .map((id) => int.parse(id.toString()))
            .toList();
        
        await _repository.assignPermissionsToRole(id, permissionIds);
        _invalidateUsersForRole(_repository, id);
      }
      
      return {
        'success': true,
        'message': 'Role updated successfully',
        'data': updatedRole.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update role: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> deleteRoleWithResponse(int id) async {
    try {
      final success = await deleteRole(id);
      return {
        'success': success,
        'message': success ? 'Role deleted successfully' : 'Role not found',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete role: $e',
      };
    }
  }

  Future<Map<String, dynamic>> assignPermissionsToRole(int roleId, List<int> permissionIds) async {
    try {
      final success = await _repository.assignPermissionsToRole(roleId, permissionIds);
      if (success) _invalidateUsersForRole(_repository, roleId);
      return {
        'success': success,
        'message': success ? 'Permissions assigned successfully' : 'Failed to assign permissions',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to assign permissions: $e',
      };
    }
  }
}

class PermissionService {
  final RolePermissionRepository _repository = RolePermissionRepository();

  Future<List<PermissionModel>> getAllPermissions() {
    return _repository.getAllPermissions();
  }

  Future<PermissionModel?> getPermissionById(int id) {
    return _repository.getPermissionById(id);
  }

  Future<PermissionModel?> getPermissionByName(String name) {
    return _repository.getPermissionByName(name);
  }

  Future<PermissionModel> createPermission(PermissionModel permission) {
    return _repository.createPermission(permission);
  }

  Future<PermissionModel> updatePermission(PermissionModel permission) {
    return _repository.updatePermission(permission);
  }

  Future<bool> deletePermission(int id) {
    return _repository.deletePermission(id);
  }

  Future<List<PermissionModel>> getPermissionsByRole(int roleId) {
    return _repository.getPermissionsByRole(roleId);
  }

  Future<List<PermissionModel>> getPermissionsByModule(String module) {
    return _repository.getPermissionsByModule(module);
  }

  Future<List<Map<String, dynamic>>> getPermissionsGroupedByModule() async {
    final permissions = await getAllPermissions();
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final permission in permissions) {
      final module = permission.module ?? 'Other';
      if (!grouped.containsKey(module)) {
        grouped[module] = [];
      }
      grouped[module]!.add(permission.toJson());
    }
    
    return grouped.entries.map((entry) => {
      'module': entry.key,
      'permissions': entry.value,
    }).toList();
  }

  Future<Map<String, dynamic>> createPermissionFromJson(Map<String, dynamic> json) async {
    try {
      final permission = PermissionModel(
        nom: json['nom'],
        module: json['module'],
        description: json['description'],
      );

      final createdPermission = await createPermission(permission);
      invalidateAllPermissionCaches();

      return {
        'success': true,
        'message': 'Permission created successfully',
        'data': createdPermission.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create permission: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> updatePermissionFromJson(int id, Map<String, dynamic> json) async {
    try {
      final permission = PermissionModel(
        id: id,
        nom: json['nom'],
        module: json['module'],
        description: json['description'],
      );

      final updatedPermission = await updatePermission(permission);
      invalidateAllPermissionCaches();

      return {
        'success': true,
        'message': 'Permission updated successfully',
        'data': updatedPermission.toJson(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update permission: $e',
        'data': null,
      };
    }
  }

  Future<Map<String, dynamic>> deletePermissionWithResponse(int id) async {
    try {
      final success = await deletePermission(id);
      if (success) invalidateAllPermissionCaches();
      return {
        'success': success,
        'message': success ? 'Permission deleted successfully' : 'Permission not found',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete permission: $e',
      };
    }
  }
}

class UserPermissionService {
  final RolePermissionRepository _repository = RolePermissionRepository();

  Future<String?> getUserRole(int userId) async {
    final role = await _repository.getUserRole(userId);
    return role?.nom;
  }

  Future<List<String>> getUserPermissions(int userId) async {
    final permissions = await _repository.getUserPermissions(userId);
    return permissions.map((p) => p.nom).toList();
  }

  Future<Map<String, dynamic>> getUserPermissionData(int userId) async {
    try {
      final role = await _repository.getUserRole(userId);
      final permissions = await _repository.getUserPermissions(userId);
      
      return {
        'success': true,
        'data': {
          'role': role,
          'permissions': permissions,
        },
        'message': 'User permissions retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to retrieve user permissions: $e',
        'data': null,
      };
    }
  }

  Future<bool> hasPermission(int userId, String permission) async {
    final permissions = await getUserPermissions(userId);
    return permissions.contains(permission);
  }

  Future<bool> hasAnyPermission(int userId, List<String> permissions) async {
    final userPermissions = await getUserPermissions(userId);
    return permissions.any((permission) => userPermissions.contains(permission));
  }

  Future<bool> hasAllPermissions(int userId, List<String> permissions) async {
    final userPermissions = await getUserPermissions(userId);
    return permissions.every((permission) => userPermissions.contains(permission));
  }

  Future<bool> assignRoleToUser(int userId, int roleId) async {
    final ok = await _repository.assignRoleToUser(userId, roleId);
    if (ok) invalidatePermissionCache(userId.toString());
    return ok;
  }

  Future<bool> removeRoleFromUser(int userId, int roleId) async {
    final ok = await _repository.removeRoleFromUser(userId, roleId);
    if (ok) invalidatePermissionCache(userId.toString());
    return ok;
  }
}
