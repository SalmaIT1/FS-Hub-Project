/// Task status workflow rules (unit-testable).
class TaskWorkflowRules {
  TaskWorkflowRules._();

  static const todo = 'À faire';
  static const inProgress = 'En cours';
  static const done = 'Terminé';
  static const blocked = 'Bloqué';

  static const Map<String, List<String>> allowedTransitions = {
    todo: [inProgress, blocked],
    inProgress: [done, blocked, todo],
    blocked: [inProgress, todo],
    done: [inProgress],
  };

  static bool canTransition(String from, String to) {
    final allowed = allowedTransitions[from];
    if (allowed == null) return false;
    return allowed.contains(to);
  }

  static bool isValidDeadline(DateTime deadline, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    return !deadline.isBefore(reference.subtract(const Duration(days: 3650)));
  }

  static bool canAssignToUser({
    required bool assigneeIsProjectMember,
    required bool assignerCanManageTasks,
  }) =>
      assigneeIsProjectMember && assignerCanManageTasks;
}
