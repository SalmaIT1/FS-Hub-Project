import '../../data/repositories/task_repository.dart';
import '../../../notification/domain/services/notification_service.dart';
import '../../../../shared/services/audit_service.dart';
import '../../../project/data/repositories/project_repository.dart';

class TaskService {
  static final _repository = TaskRepository();
  static final _projectRepo = ProjectRepository();

  static Future<List<Map<String, dynamic>>> getAllTasks() async {
    final tasks = await _repository.getAllTasks();
    return tasks.map((t) => t.toJson()).toList();
  }

  static Future<List<Map<String, dynamic>>> getMyTasks(String userId) async {
    final tasks = await _repository.getMyTasks(userId);
    return tasks.map((t) => t.toJson()).toList();
  }

  static Future<List<Map<String, dynamic>>> getTasksBySprint(int sprintId, {String? callerRole, String? callerId}) async {
    // RBAC: Check if user belongs to project or is admin
    final sprint = await _repository.getSprintInfo(sprintId);
    if (sprint == null) return [];
    
    if (callerRole != 'Admin' && callerRole != 'Manager' && callerRole != 'RH' && callerId != null && sprint.projectId != null) {
      final isMember = await _projectRepo.isMember(sprint.projectId!, callerId);
      final isOwner = await _projectRepo.isClientOwner(sprint.projectId!, callerId);
      if (!isMember && !isOwner) return [];
    }

    final tasks = await _repository.getTasksBySprint(sprintId);
    return tasks.map((t) => t.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getTaskById(int id, {String? callerRole, String? callerId}) async {
    final task = await _repository.getTaskById(id);
    if (task == null) return null;
    
    if (callerRole != 'Admin' && callerRole != 'Manager' && callerRole != 'RH' && callerId != null && task.sprintId != null) {
      final sprint = await _repository.getSprintInfo(task.sprintId!);
      if (sprint == null || sprint.projectId == null) return null;
      
      final isMember = await _projectRepo.isMember(sprint.projectId!, callerId);
      final isOwner = await _projectRepo.isClientOwner(sprint.projectId!, callerId);
      if (!isMember && !isOwner) return null;
    }
    
    return task.toJson();
  }

  static Future<void> createTask(Map<String, dynamic> data, {String? callerId}) async {
    final id = await _repository.createTask(data);
    await AuditService.log(callerId ?? 'SYSTEM', 'TASK_CREATED', {
      'taskId': id,
      'title': data['titre'],
      'sprintId': data['sprint_id'],
    });
    if (data['employee_id'] != null) {
      await NotificationService.createNotification(
        userId: data['employee_id'].toString(),
        title: 'New Task Assigned',
        message: "You have been assigned a new task: ${data['titre']}",
        type: 'TASK_ASSIGNED',
      );
    }
  }

  static Future<void> updateTask(int id, Map<String, dynamic> data, String userId, List<String> permissions, bool isAdmin) async {
    final existing = await _repository.getTaskById(id);
    if (existing == null) throw Exception('Task not found');

    if (!isAdmin && !permissions.contains('manage_tasks') && permissions.contains('update_task_progress')) {
      if (existing.employeeId != userId) {
        throw Exception('Permission denied: You can only update progress on tasks assigned to you');
      }
      // Strip out anything else except status and real hours
      final allowedData = {
        'employeeId': existing.employeeId,
        'titre': existing.titre,
        'description': existing.description,
        'estimationHeures': existing.estimationHeures,
        'heuresReelles': data['heuresReelles'] ?? existing.heuresReelles,
        'statut': data['statut'] ?? existing.statut,
        'priorite': existing.priorite,
      };
      await _repository.updateTask(id, allowedData);
      return;
    }

    await _repository.updateTask(id, data);
    
    await AuditService.log(userId, 'TASK_UPDATED', {
      'taskId': id,
      'fields': data.keys.toList(),
    });
    
    // Notify if assignment changed or status changed
    if (data['employee_id'] != null && data['employee_id'] != existing.employeeId) {
      await NotificationService.createNotification(
        userId: data['employee_id'].toString(),
        title: 'Task Assigned',
        message: 'You have been assigned to task: ${data['titre'] ?? existing.titre}',
        type: 'TASK_ASSIGNED',
      );
    }
  }

  static Future<void> deleteTask(int id, {String? callerId}) async {
    final task = await _repository.getTaskById(id);
    await _repository.deleteTask(id);
    await AuditService.log(callerId ?? 'SYSTEM', 'TASK_DELETED', {
      'taskId': id,
      'title': task?.titre,
    });
  }

  static Future<Map<String, dynamic>> bulkAssignTasks(List<int> taskIds, String employeeId, {String? callerId}) async {
    try {
      // P1 FIX: Parallelize DB updates to prevent event-loop congestion
      final tasks = taskIds.map((id) => _repository.updateTask(id, {'employee_id': employeeId}));
      await Future.wait(tasks);

      final count = taskIds.length;
      await NotificationService.createNotification(
        userId: employeeId,
        title: 'Bulk Tasks Assigned',
        message: 'You have been assigned $count new tasks.',
        type: 'TASK_ASSIGNED',
      );

      await AuditService.log(callerId ?? 'SYSTEM', 'BULK_TASK_ASSIGNMENT', {
        'employeeId': employeeId,
        'taskCount': count,
        'taskIds': taskIds,
      });

      return {'success': true, 'message': 'Successfully assigned $count tasks'};
    } catch (e) {
      return {'success': false, 'message': 'Bulk assignment failed: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> getBurndownData(int sprintId, {String? callerRole, String? callerId}) async {
    final sprint = await _repository.getSprintInfo(sprintId);
    if (sprint == null || sprint.dateDebut == null || sprint.dateFin == null) {
      throw Exception('Sprint not found or dates missing');
    }

    if (callerRole != 'Admin' && callerRole != 'Manager' && callerRole != 'RH' && callerId != null && sprint.projectId != null) {
      final isMember = await _projectRepo.isMember(sprint.projectId!, callerId);
      final isOwner = await _projectRepo.isClientOwner(sprint.projectId!, callerId);
      if (!isMember && !isOwner) throw Exception('Permission denied');
    }

    final dateDebut = DateTime.parse(sprint.dateDebut!);
    final dateFin = DateTime.parse(sprint.dateFin!);
    final duration = dateFin.difference(dateDebut).inDays + 1;

    final tasks = await _repository.getTasksBySprint(sprintId);
    final totalHours = tasks.fold<double>(0, (sum, t) => sum + t.estimationHeures);

    double finishedBefore = 0;
    for (var t in tasks) {
      if (t.statut == 'Done' && t.updatedAt != null) {
        final updated = DateTime.parse(t.updatedAt!);
        if (updated.isBefore(dateDebut)) finishedBefore += t.estimationHeures;
      }
    }

    List<Map<String, dynamic>> data = [];
    double remaining = totalHours - finishedBefore;
    final now = DateTime.now();
    
    for (int i = 0; i < duration; i++) {
      final currentDay = dateDebut.add(Duration(days: i));
      
      double finishedToday = 0;
      for (var t in tasks) {
        if (t.statut == 'Done' && t.updatedAt != null) {
          final updated = DateTime.parse(t.updatedAt!);
          if (updated.year == currentDay.year && updated.month == currentDay.month && updated.day == currentDay.day) {
             finishedToday += t.estimationHeures;
          }
        }
      }
      
      remaining -= finishedToday;
      double ideal = 0;
      if (duration > 1) {
        ideal = totalHours - (i * (totalHours / (duration - 1)));
      } else {
        ideal = 0; // Handle duration <= 1
      }

      bool isPastOrToday = currentDay.isBefore(now) || 
                          (currentDay.year == now.year && currentDay.month == now.month && currentDay.day == now.day);

      data.add({
        'day': i,
        'ideal': ideal < 0 ? 0 : ideal,
        'actual': isPastOrToday ? (remaining < 0 ? 0 : remaining) : null,
        'date': currentDay.toIso8601String().split('T')[0]
      });
    }

    return data;
  }
}
