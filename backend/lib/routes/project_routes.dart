import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';
import '../services/data_integrity_service.dart';

class ProjectRoutes {
  late final Router router;

  ProjectRoutes() {
    router = Router()
      ..get('/', _getAllProjects)
      ..get('/available-employees', _getAvailableEmployees)
      ..get('/check-deadlines', _manualCheckDeadlines)
      ..get('/<id>', _getProjectById)
      ..post('/', _createProject)
      ..put('/<id>', _updateProject)
      ..delete('/<id>', _deleteProject)
      // Member management
      ..get('/<id>/members', _getProjectMembers)
      ..post('/<id>/members', _addProjectMember)
      ..delete('/<id>/members/<employeeId>', _removeProjectMember);
  }

  Future<Response> _getAllProjects(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT p.*, c.nom as client_nom, c.prenom as client_prenom, c.raison_sociale as client_raison_sociale
        FROM projets p
        LEFT JOIN clients c ON p.client_id = c.id
        ORDER BY p.id DESC
      ''');

      final projects = result.rows.map((row) {
        final data = row.assoc();
        return {
          'id': data['id'] != null ? int.tryParse(data['id'].toString()) : null,
          'nom': data['nom'],
          'description': data['description'],
          'clientId': data['client_id'] != null ? int.tryParse(data['client_id'].toString()) : null,
          'clientName': _formatClientName(data),
          'budget': data['budget'] != null ? double.tryParse(data['budget'].toString()) : 0.0,
          'coutEstime': data['cout_estime'] != null ? double.tryParse(data['cout_estime'].toString()) : 0.0,
          'dateDebut': data['date_debut']?.toString(),
          'dateFinPrevue': data['date_fin_prevue']?.toString(),
          'priorite': data['priorite'],
          'statut': data['statut'],
          'createdAt': data['created_at']?.toString(),
          'updatedAt': data['updated_at']?.toString(),
        };
      }).toList();

      return Response.ok(
        jsonEncode(projects),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Error loading projects: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load projects: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  String _formatClientName(Map<String, String?> data) {
    final rs = data['client_raison_sociale'];
    if (rs != null && rs.isNotEmpty) return rs;
    final nom = data['client_nom'] ?? '';
    final prenom = data['client_prenom'] ?? '';
    return '$nom $prenom'.trim();
  }

  Future<Response> _manualCheckDeadlines(Request request) async {
    try {
      await DataIntegrityService.checkDeadlines(); // renamed from _checkDeadlines
      return Response.ok(jsonEncode({'success': true, 'message': 'Deadlines checked'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getProjectById(Request request) async {
    try {
      final idString = request.params['id']!;
      final id = int.tryParse(idString);
      
      if (id == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid project ID format'}));
      }

      final conn = DBConnection.getConnection();
      final result = await conn.execute('''
        SELECT p.*, c.nom as client_nom, c.prenom as client_prenom, c.raison_sociale as client_raison_sociale
        FROM projets p
        LEFT JOIN clients c ON p.client_id = c.id
        WHERE p.id = :id
      ''', {'id': id});

      if (result.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Project not found'}));
      }

      final data = result.rows.first.assoc();
      final project = {
        'id': data['id'] != null ? int.tryParse(data['id'].toString()) : null,
        'nom': data['nom'],
        'description': data['description'],
        'clientId': data['client_id'] != null ? int.tryParse(data['client_id'].toString()) : null,
        'clientName': _formatClientName(data),
        'budget': data['budget'] != null ? double.tryParse(data['budget'].toString()) : 0.0,
        'coutEstime': data['cout_estime'] != null ? double.tryParse(data['cout_estime'].toString()) : 0.0,
        'dateDebut': data['date_debut']?.toString(),
        'dateFinPrevue': data['date_fin_prevue']?.toString(),
        'priorite': data['priorite'],
        'statut': data['statut'],
        'createdAt': data['created_at']?.toString(),
        'updatedAt': data['updated_at']?.toString(),
      };

      return Response.ok(
        jsonEncode(project),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Error loading project: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load project: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _createProject(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final conn = DBConnection.getConnection();
      
      await conn.execute('''
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
        'client_id': data['clientId'] != null ? int.tryParse(data['clientId'].toString()) : null,
        'budget': data['budget'] != null ? double.tryParse(data['budget'].toString()) : 0.0,
        'cout_estime': data['coutEstime'] != null ? double.tryParse(data['coutEstime'].toString()) : 0.0,
        'date_debut': data['dateDebut'],
        'date_fin_prevue': data['dateFinPrevue'],
        'priorite': data['priorite'],
        'statut': data['statut'],
      });

      final idResult = await conn.execute('SELECT LAST_INSERT_ID() as id');
      final newId = idResult.rows.first.colByName('id');

      return Response(201, 
        body: jsonEncode({'success': true, 'id': int.tryParse(newId.toString()), 'message': 'Project created successfully'}),
        headers: {'Content-Type': 'application/json'}
      );
    } catch (e, stack) {
      print('Error creating project: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create project: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _updateProject(Request request) async {
    try {
      final idString = request.params['id']!;
      final id = int.tryParse(idString);
      
      if (id == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid project ID format'}));
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final conn = DBConnection.getConnection();
      
      await conn.execute('''
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
        'client_id': data['clientId'] != null ? int.tryParse(data['clientId'].toString()) : null,
        'budget': data['budget'] != null ? double.tryParse(data['budget'].toString()) : 0.0,
        'cout_estime': data['coutEstime'] != null ? double.tryParse(data['coutEstime'].toString()) : 0.0,
        'date_debut': data['dateDebut'],
        'date_fin_prevue': data['dateFinPrevue'],
        'priorite': data['priorite'],
        'statut': data['statut'],
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Project updated successfully'}),
        headers: {'Content-Type': 'application/json'}
      );
    } catch (e, stack) {
      print('Error updating project: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update project: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _deleteProject(Request request) async {
    try {
      final idString = request.params['id']!;
      final id = int.tryParse(idString);
      
      if (id == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid project ID format'}));
      }

      final conn = DBConnection.getConnection();
      await conn.execute('DELETE FROM projets WHERE id = :id', {'id': id});

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Project deleted successfully'}),
        headers: {'Content-Type': 'application/json'}
      );
    } catch (e, stack) {
      print('Error deleting project: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete project: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getAvailableEmployees(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
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

      final employees = result.rows.map((row) {
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

      return Response.ok(
        jsonEncode(employees),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Error loading available employees: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load available employees: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getProjectMembers(Request request) async {
    try {
      final projectId = request.params['id'];
      final conn = DBConnection.getConnection();
      
      final result = await conn.execute('''
        SELECT pm.id as membership_id, pm.role, pm.joined_at, 
               e.*, d.nom as dept_name
        FROM projet_membres pm
        JOIN employees e ON pm.employee_id = e.id
        LEFT JOIN departements d ON e.departement = d.id
        WHERE pm.projet_id = :id
      ''', {'id': projectId});

      final members = result.rows.map((row) {
        final data = row.assoc();
        return {
          'id': data['membership_id'],
          'employeeId': data['id'],
          'nom': data['nom'],
          'prenom': data['prenom'],
          'matricule': data['matricule'],
          'role': data['role'],
          'poste': data['poste'],
          'email': data['email'],
          'departement': data['dept_name'],
          'photo': data['photo'],
          'joinedAt': data['joined_at']?.toString(),
        };
      }).toList();

      return Response.ok(
        jsonEncode(members),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Error loading project members: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load project members: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _addProjectMember(Request request) async {
    try {
      final projectId = request.params['id'];
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final employeeId = data['employeeId'];
      final role = data['role'] ?? 'Membre';

      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        INSERT INTO projet_membres (projet_id, employee_id, role)
        VALUES (:proj, :emp, :role)
      ''', {
        'proj': projectId,
        'emp': employeeId,
        'role': role,
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Member added successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Error adding project member: $e\n$stack');
      if (e.toString().contains('Duplicate entry')) {
        return Response.badRequest(
          body: jsonEncode({'error': 'This employee is already in the project team'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to add member: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _removeProjectMember(Request request) async {
    try {
      final projectId = request.params['id'];
      final employeeId = request.params['employeeId'];
      
      final conn = DBConnection.getConnection();
      await conn.execute('''
        DELETE FROM projet_membres 
        WHERE projet_id = :proj AND employee_id = :emp
      ''', {
        'proj': projectId,
        'emp': employeeId,
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Member removed successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Error removing project member: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to remove member: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
