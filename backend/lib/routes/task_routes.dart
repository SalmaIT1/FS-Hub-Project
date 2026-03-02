import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';

class TaskRoutes {
  late final Router router;

  TaskRoutes() {
    router = Router()
      ..get('/', _getAllTasks)
      ..get('/my-tasks', _getMyTasks)
      ..get('/sprint/<sprintId>', _getTasksBySprint)
      ..get('/<id>', _getTaskById)
      ..get('/sprint/<sprintId>/burndown', _getBurndownData)
      ..post('/', _createTask)
      ..put('/<id>', _updateTask)
      ..delete('/<id>', _deleteTask);
  }

  Future<Response> _getAllTasks(Request request) async {
    try {
      final conn = DBConnection.getConnection();
      final result = await conn.execute('SELECT * FROM taches ORDER BY id DESC');
      final tasks = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getMyTasks(Request request) async {
    try {
      // Assuming userId is passed via a header or we can extract it if we had a proper user context
      // For now, lets look for a 'X-User-Id' header which our AuthService should be sending
      final userId = request.headers['X-User-Id'] ?? request.headers['x-user-id'];
      
      print('[DEBUG] _getMyTasks: headers=${request.headers}');
      print('[DEBUG] _getMyTasks: userId=$userId');
      
      if (userId == null) {
        return Response.badRequest(body: jsonEncode({'error': 'User ID required'}));
      }

      final conn = DBConnection.getConnection();
      final result = await conn.execute('''
        SELECT t.*, s.nom as sprint_nom, p.nom as project_nom
        FROM taches t
        JOIN sprints s ON t.sprint_id = s.id
        JOIN projets p ON s.projet_id = p.id
        WHERE t.employee_id = :userId
        ORDER BY t.priorite DESC, t.updated_at DESC
      ''', {'userId': userId});

      final tasks = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getTasksBySprint(Request request) async {
    try {
      final sprintId = request.params['sprintId'];
      final conn = DBConnection.getConnection();
      final result = await conn.execute('''
        SELECT t.*, e.nom as employee_nom, e.prenom as employee_prenom 
        FROM taches t
        LEFT JOIN employees e ON t.employee_id = e.id
        WHERE t.sprint_id = :sid
      ''', {'sid': sprintId});

      final tasks = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(tasks), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getTaskById(Request request) async {
    try {
      final id = request.params['id'];
      final conn = DBConnection.getConnection();
      final result = await conn.execute('SELECT * FROM taches WHERE id = :id', {'id': id});
      
      if (result.rows.isEmpty) return Response.notFound(jsonEncode({'error': 'Task not found'}));
      
      return Response.ok(jsonEncode(result.rows.first.assoc()), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _createTask(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      print('[DEBUG] _createTask: data=$data');
      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        INSERT INTO taches (sprint_id, employee_id, titre, description, estimation_heures, statut, priorite)
        VALUES (:sid, :eid, :titre, :desc, :est, :stat, :prio)
      ''', {
        'sid': data['sprint_id'],
        'eid': data['employee_id'],
        'titre': data['titre'],
        'desc': data['description'],
        'est': data['estimation_heures'],
        'stat': data['statut'] ?? 'ToDo',
        'prio': data['priorite'] ?? 'Medium',
      });

      return Response(201, body: jsonEncode({'success': true, 'message': 'Task created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _updateTask(Request request) async {
    try {
      final id = request.params['id'];
      final data = jsonDecode(await request.readAsString());
      final conn = DBConnection.getConnection();
      
      await conn.execute('''
        UPDATE taches SET 
          employee_id = :eid, titre = :titre, description = :desc, 
          estimation_heures = :est, heures_reelles = :reel, 
          statut = :stat, priorite = :prio
        WHERE id = :id
      ''', {
        'id': id,
        'eid': data['employee_id'],
        'titre': data['titre'],
        'desc': data['description'],
        'est': data['estimation_heures'],
        'reel': data['heures_reelles'],
        'stat': data['statut'],
        'prio': data['priorite'],
      });

      return Response.ok(jsonEncode({'success': true, 'message': 'Task updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _deleteTask(Request request) async {
    try {
      final id = request.params['id'];
      final conn = DBConnection.getConnection();
      await conn.execute('DELETE FROM taches WHERE id = :id', {'id': id});
      return Response.ok(jsonEncode({'success': true, 'message': 'Task deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getBurndownData(Request request) async {
    try {
      final sprintId = request.params['sprintId'];
      final conn = DBConnection.getConnection();
      
      print('[DEBUG] _getBurndownData: sprintId=$sprintId');

      // Get sprint details
      final sprintRes = await conn.execute('SELECT * FROM sprints WHERE id = :sid', {'sid': sprintId});
      if (sprintRes.rows.isEmpty) return Response.notFound(jsonEncode({'error': 'Sprint not found'}));
      
      final sprint = sprintRes.rows.first.assoc();
      final dateDebutStr = sprint['date_debut'];
      final dateFinStr = sprint['date_fin'];

      if (dateDebutStr == null || dateFinStr == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Sprint dates are missing'}));
      }

      final dateDebut = DateTime.parse(dateDebutStr);
      final dateFin = DateTime.parse(dateFinStr);
      final duration = dateFin.difference(dateDebut).inDays + 1;

      // Get all tasks for this sprint
      final tasksRes = await conn.execute('SELECT * FROM taches WHERE sprint_id = :sid', {'sid': sprintId});
      final tasks = tasksRes.rows.map((r) => r.assoc()).toList();
      
      print('[DEBUG] _getBurndownData: found ${tasks.length} tasks');

      final totalHours = tasks.fold<double>(0, (sum, t) => sum + (double.tryParse(t['estimation_heures']?.toString() ?? '0') ?? 0));
      
      // Calculate work already finished BEFORE the sprint started
      double finishedBefore = 0;
      for (var t in tasks) {
        if (t['statut'] == 'Done' && t['updated_at'] != null) {
          final updated = DateTime.parse(t['updated_at']!);
          if (updated.isBefore(dateDebut)) {
            finishedBefore += double.tryParse(t['estimation_heures']?.toString() ?? '0') ?? 0;
          }
        }
      }

      List<Map<String, dynamic>> data = [];
      double remaining = totalHours - finishedBefore;
      final now = DateTime.now();
      
      for (int i = 0; i < duration; i++) {
        final currentDay = dateDebut.add(Duration(days: i));
        
        // Calculate work finished EXACTLY on this day
        double finishedToday = 0;
        for (var t in tasks) {
          if (t['statut'] == 'Done' && t['updated_at'] != null) {
            final updated = DateTime.parse(t['updated_at']!);
            if (updated.year == currentDay.year && updated.month == currentDay.month && updated.day == currentDay.day) {
               finishedToday += double.tryParse(t['estimation_heures']?.toString() ?? '0') ?? 0;
            }
          }
        }
        
        remaining -= finishedToday;
        
        // Calculate ideal for this day
        double ideal = 0;
        if (duration > 1) {
          ideal = totalHours - (i * (totalHours / (duration - 1)));
        } else {
          ideal = i == 0 ? totalHours : 0;
        }

        // Add point
        // If the day is in the past or today, we show actual work. Otherwise null.
        bool isPastOrToday = currentDay.isBefore(now) || 
                            (currentDay.year == now.year && currentDay.month == now.month && currentDay.day == now.day);

        data.add({
          'day': i,
          'ideal': ideal < 0 ? 0 : ideal,
          'actual': isPastOrToday ? (remaining < 0 ? 0 : remaining) : null,
          'date': currentDay.toIso8601String().split('T')[0]
        });
      }

      print('[DEBUG] _getBurndownData: returning ${data.length} data points');
      return Response.ok(jsonEncode(data), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('[ERROR] Burndown chart: $e');
      print(stack);
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}
