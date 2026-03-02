import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';

class DepartmentRoutes {
  late final Router router;

  DepartmentRoutes() {
    router = Router()
      ..get('/', _getAllDepartments)
      ..get('/<id>', _getDepartmentById)
      ..post('/', _createDepartment)
      ..put('/<id>', _updateDepartment)
      ..delete('/<id>', _deleteDepartment);
  }

  Future<Response> _getAllDepartments(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT id, nom, budget_annuel, created_at, updated_at
        FROM departements
        ORDER BY nom ASC
      ''');

      final departments = result.rows.map((row) {
        final data = row.assoc();
        return {
          'id': data['id'] != null ? int.tryParse(data['id'].toString()) : null,
          'nom': data['nom'],
          'budgetAnnuel': data['budget_annuel'] != null ? double.tryParse(data['budget_annuel'].toString()) : 0.0,
          'createdAt': data['created_at']?.toString(),
          'updatedAt': data['updated_at']?.toString(),
        };
      }).toList();

      return Response.ok(
        jsonEncode({'success': true, 'data': departments}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('DEBUG: Error fetching departments: $e');
      print('STACKTRACE: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Internal Server Error: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getDepartmentById(Request request, String id) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT id, nom, budget_annuel, created_at, updated_at
        FROM departements
        WHERE id = :id
      ''', {'id': id});

      if (result.rows.isEmpty) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Department not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final data = result.rows.first.assoc();
      final department = {
        'id': data['id'] != null ? int.tryParse(data['id'].toString()) : null,
        'nom': data['nom'],
        'budgetAnnuel': data['budget_annuel'] != null ? double.tryParse(data['budget_annuel'].toString()) : 0.0,
        'createdAt': data['created_at']?.toString(),
        'updatedAt': data['updated_at']?.toString(),
      };

      return Response.ok(
        jsonEncode({'success': true, 'data': department}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('DEBUG: Error fetching department: $e');
      print('STACKTRACE: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Internal Server Error: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _createDepartment(Request request) async {
    try {
      final body = await request.readAsString();
      print('DEBUG: Create department body: $body');
      final data = jsonDecode(body);

      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        INSERT INTO departements (nom, budget_annuel)
        VALUES (:nom, :budget_annuel)
      ''', {
        'nom': data['nom'],
        'budget_annuel': data['budgetAnnuel'] ?? 0.0,
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Department created successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('DEBUG: Error creating department: $e');
      print('STACKTRACE: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Internal Server Error: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _updateDepartment(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        UPDATE departements 
        SET nom = :nom, budget_annuel = :budget_annuel, updated_at = NOW()
        WHERE id = :id
      ''', {
        'nom': data['nom'],
        'budget_annuel': data['budgetAnnuel'] ?? 0.0,
        'id': id,
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Department updated successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('DEBUG: Error updating department: $e');
      print('STACKTRACE: $stack');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Internal Server Error: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _deleteDepartment(Request request, String id) async {
    try {
      final conn = DBConnection.getConnection();
      
      // Check if any employees are linked to this department before deleting or just allow it.
      // Usually it's better to check.
      
      await conn.execute('DELETE FROM departements WHERE id = :id', {'id': id});

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Department deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error deleting department: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
