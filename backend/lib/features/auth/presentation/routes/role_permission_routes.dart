import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/role_permission_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';
import '../../data/models/role_permission_model.dart';

class RolePermissionRoutes {
  final RoleService _roleService = RoleService();
  final PermissionService _permissionService = PermissionService();
  final UserPermissionService _userPermissionService = UserPermissionService();
  final Router _router = Router();

  RolePermissionRoutes() {
    _setupRoutes();
  }

  void _setupRoutes() {
    // Permission routes — All require manage_permissions
    _router.get('/permissions', Pipeline().addMiddleware(requirePermission('manage_permissions')).addHandler(_getAllPermissions));
    _router.get('/permissions/grouped', Pipeline().addMiddleware(requirePermission('manage_permissions')).addHandler(_getPermissionsGroupedByModule));
    _router.get('/permissions/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_permissions')).addHandler((req) => _getPermissionById(req, id))(request));
    _router.post('/permissions', Pipeline().addMiddleware(requirePermission('manage_permissions')).addHandler(_createPermission));
    _router.put('/permissions/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_permissions')).addHandler((req) => _updatePermission(req, id))(request));
    _router.delete('/permissions/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_permissions')).addHandler((req) => _deletePermission(req, id))(request));
    _router.get('/permissions/module/<module>', (Request request, String module) => Pipeline().addMiddleware(requirePermission('manage_permissions')).addHandler((req) => _getPermissionsByModule(req, module))(request));

    // User permission routes - This one is for the current user to see their own
    _router.get('/user/permissions', _getUserPermissions);

    // Role routes — All require manage_roles
    _router.get('/', Pipeline().addMiddleware(requirePermission('manage_roles')).addHandler(_getAllRoles));
    _router.post('/', Pipeline().addMiddleware(requirePermission('manage_roles')).addHandler(_createRole));
    _router.get('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_roles')).addHandler((req) => _getRoleById(req, id))(request));
    _router.put('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_roles')).addHandler((req) => _updateRole(req, id))(request));
    _router.delete('/<id>', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_roles')).addHandler((req) => _deleteRole(req, id))(request));
    _router.get('/<id>/permissions', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_roles')).addHandler((req) => _getRolePermissions(req, id))(request));
    _router.post('/<id>/permissions', (Request request, String id) => Pipeline().addMiddleware(requirePermission('manage_roles')).addHandler((req) => _assignPermissionsToRole(req, id))(request));
  }

  // Role handlers
  Future<Response> _getAllRoles(Request request) async {
    try {
      final rolesWithPermissions = await _roleService.getRolesWithPermissions();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': rolesWithPermissions,
          'message': 'Roles retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, st) {
      print('Exception in _getAllRoles: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve roles: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getRoleById(Request request, String id) async {
    try {
      final roleId = int.parse(id);
      final role = await _roleService.getRoleById(roleId);
      
      if (role == null) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'Role not found',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final permissions = await _permissionService.getPermissionsByRole(roleId!);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            ...role.toJson(),
            'permissions': permissions.map((p) => p?.toJson() ?? {}).toList(),
          },
          'message': 'Role retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve role: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _createRole(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _roleService.createRoleFromJson(json);
      
      return Response(
        result['success'] ? 201 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create role: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _updateRole(Request request, String id) async {
    try {
      final roleId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _roleService.updateRoleFromJson(roleId, json);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to update role: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _deleteRole(Request request, String id) async {
    try {
      final roleId = int.parse(id);
      final result = await _roleService.deleteRoleWithResponse(roleId);
      
      return Response(
        result['success'] ? 200 : 404,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to delete role: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getRolePermissions(Request request, String id) async {
    try {
      final roleId = int.parse(id);
      final permissions = await _permissionService.getPermissionsByRole(roleId);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': permissions.map((p) => p?.toJson() ?? {}).toList(),
          'message': 'Role permissions retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve role permissions: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _assignPermissionsToRole(Request request, String id) async {
    try {
      final roleId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      if (json['permission_ids'] == null) {
        return Response(400, body: jsonEncode({
          'success': false,
          'message': 'permission_ids is required',
        }), headers: {'content-type': 'application/json'});
      }
      
      final permissionIds = (json['permission_ids'] as List)
          .map((id) => int.parse(id.toString()))
          .toList();
      
      final result = await _roleService.assignPermissionsToRole(roleId, permissionIds);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to assign permissions: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // Permission handlers
  Future<Response> _getAllPermissions(Request request) async {
    try {
      final permissions = await _permissionService.getAllPermissions();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': permissions.map((p) => p?.toJson() ?? {}).toList(),
          'message': 'Permissions retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, st) {
      print('Exception in _getAllPermissions: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve permissions: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getPermissionsGroupedByModule(Request request) async {
    try {
      final groupedPermissions = await _permissionService.getPermissionsGroupedByModule();
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': groupedPermissions,
          'message': 'Permissions grouped by module retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, st) {
      print('Exception in _getPermissionsGroupedByModule: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve grouped permissions: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getPermissionById(Request request, String id) async {
    try {
      final permissionId = int.parse(id);
      final permission = await _permissionService.getPermissionById(permissionId);
      
      if (permission == null) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'Permission not found',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': permission?.toJson() ?? {},
          'message': 'Permission retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve permission: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _createPermission(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _permissionService.createPermissionFromJson(json);
      
      return Response(
        result['success'] ? 201 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to create permission: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _updatePermission(Request request, String id) async {
    try {
      final permissionId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final result = await _permissionService.updatePermissionFromJson(permissionId, json);
      
      return Response(
        result['success'] ? 200 : 400,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to update permission: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _deletePermission(Request request, String id) async {
    try {
      final permissionId = int.parse(id);
      final result = await _permissionService.deletePermissionWithResponse(permissionId);
      
      return Response(
        result['success'] ? 200 : 404,
        body: jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to delete permission: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getPermissionsByModule(Request request, String module) async {
    try {
      final permissions = await _permissionService.getPermissionsByModule(module);
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': permissions.map((p) => p?.toJson() ?? {}).toList(),
          'message': 'Permissions for module retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve permissions for module: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // User permission handlers
  Future<Response> _getUserPermissions(Request request) async {
    try {
      final userId = request.authUserId;
      if (userId.isEmpty) {
        return Response(401, body: jsonEncode({
          'success': false,
          'message': 'User not authenticated',
        }), headers: {'content-type': 'application/json'});
      }

      final permissions = request.authUserPermissions;
      final role = request.authUserRole;
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'role': role,
            'permissions': permissions,
          },
          'message': 'User permissions retrieved successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve user permissions: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Router get router {
    return _router;
  }
}
