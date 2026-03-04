import '../../data/repositories/task_repository.dart';

class TaskService {
  static final _repository = TaskRepository();

  static Future<List<Map<String, dynamic>>> getAllTasks() async {
    final tasks = await _repository.getAllTasks();
    return tasks.map((t) => t.toJson()).toList();
  }

  static Future<List<Map<String, dynamic>>> getMyTasks(String userId) async {
    final tasks = await _repository.getMyTasks(userId);
    return tasks.map((t) => t.toJson()).toList();
  }

  static Future<List<Map<String, dynamic>>> getTasksBySprint(int sprintId) async {
    final tasks = await _repository.getTasksBySprint(sprintId);
    return tasks.map((t) => t.toJson()).toList();
  }

  static Future<Map<String, dynamic>?> getTaskById(int id) async {
    final task = await _repository.getTaskById(id);
    return task?.toJson();
  }

  static Future<void> createTask(Map<String, dynamic> data) async {
    await _repository.createTask(data);
  }

  static Future<void> updateTask(int id, Map<String, dynamic> data) async {
    await _repository.updateTask(id, data);
  }

  static Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
  }

  static Future<List<Map<String, dynamic>>> getBurndownData(int sprintId) async {
    final sprint = await _repository.getSprintInfo(sprintId);
    if (sprint == null || sprint.dateDebut == null || sprint.dateFin == null) {
      throw Exception('Sprint not found or dates missing');
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
        ideal = i == 0 ? totalHours : 0;
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
