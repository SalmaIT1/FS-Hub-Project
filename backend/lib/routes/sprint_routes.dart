import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';

class SprintRoutes {
  late final Router router;

  SprintRoutes() {
    router = Router()
      ..get('/project/<projectId>', _getSprintsByProject)
      ..get('/<id>', _getSprintById)
      ..post('/', _createSprint)
      ..put('/<id>', _updateSprint)
      ..delete('/<id>', _deleteSprint);
  }

  Future<Response> _getSprintsByProject(Request request, String projectId) async {
    try {
      final pid = int.tryParse(projectId);
      if (pid == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid project ID'}));
      }

      final conn = DBConnection.getConnection();
      final result = await conn.execute(
        'SELECT * FROM sprints WHERE projet_id = :pid ORDER BY date_debut ASC',
        {'pid': pid}
      );

      final sprints = result.rows.map((row) {
        final data = row.assoc();
        return {
          'id': int.tryParse(data['id'].toString()),
          'projectId': int.tryParse(data['projet_id'].toString()),
          'nom': data['nom'],
          'dateDebut': data['date_debut']?.toString(),
          'dateFin': data['date_fin']?.toString(),
          'objectif': data['objectif'],
          'createdAt': data['created_at']?.toString(),
          'updatedAt': data['updated_at']?.toString(),
        };
      }).toList();

      return Response.ok(
        jsonEncode(sprints),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getSprintById(Request request, String id) async {
    try {
      final sid = int.tryParse(id);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));

      final conn = DBConnection.getConnection();
      final result = await conn.execute('SELECT * FROM sprints WHERE id = :id', {'id': sid});

      if (result.rows.isEmpty) return Response.notFound(jsonEncode({'error': 'Sprint not found'}));

      final data = result.rows.first.assoc();
      return Response.ok(
        jsonEncode({
          'id': int.tryParse(data['id'].toString()),
          'projectId': int.tryParse(data['projet_id'].toString()),
          'nom': data['nom'],
          'dateDebut': data['date_debut']?.toString(),
          'dateFin': data['date_fin']?.toString(),
          'objectif': data['objectif'],
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _createSprint(Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      final conn = DBConnection.getConnection();
      
      await conn.execute(
        '''INSERT INTO sprints (projet_id, nom, date_debut, date_fin, objectif) 
           VALUES (:pid, :nom, :debut, :fin, :obj)''',
        {
          'pid': payload['projectId'],
          'nom': payload['nom'],
          'debut': payload['dateDebut'],
          'fin': payload['dateFin'],
          'obj': payload['objectif'],
        }
      );

      return Response(201, body: jsonEncode({'success': true, 'message': 'Sprint created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _updateSprint(Request request, String id) async {
    try {
      final sid = int.tryParse(id);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final payload = jsonDecode(await request.readAsString());
      final conn = DBConnection.getConnection();
      
      await conn.execute(
        '''UPDATE sprints SET nom = :nom, date_debut = :debut, date_fin = :fin, objectif = :obj 
           WHERE id = :id''',
        {
          'id': sid,
          'nom': payload['nom'],
          'debut': payload['dateDebut'],
          'fin': payload['dateFin'],
          'obj': payload['objectif'],
        }
      );

      return Response.ok(jsonEncode({'success': true, 'message': 'Sprint updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _deleteSprint(Request request, String id) async {
    try {
      final sid = int.tryParse(id);
      if (sid == null) return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      
      final conn = DBConnection.getConnection();
      await conn.execute('DELETE FROM sprints WHERE id = :id', {'id': sid});

      return Response.ok(jsonEncode({'success': true, 'message': 'Sprint deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}
