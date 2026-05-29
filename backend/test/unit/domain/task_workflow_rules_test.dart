import 'package:test/test.dart';
import 'package:fs_hub_backend/shared/domain/task_workflow_rules.dart';

void main() {
  group('TaskWorkflowRules — assign task', () {
    test('valid status transitions', () {
      expect(
        TaskWorkflowRules.canTransition(
          TaskWorkflowRules.todo,
          TaskWorkflowRules.inProgress,
        ),
        isTrue,
      );
      expect(
        TaskWorkflowRules.canTransition(
          TaskWorkflowRules.done,
          TaskWorkflowRules.todo,
        ),
        isFalse,
      );
    });

    test('assign requires project membership and manage_tasks', () {
      expect(
        TaskWorkflowRules.canAssignToUser(
          assigneeIsProjectMember: true,
          assignerCanManageTasks: true,
        ),
        isTrue,
      );
      expect(
        TaskWorkflowRules.canAssignToUser(
          assigneeIsProjectMember: false,
          assignerCanManageTasks: true,
        ),
        isFalse,
      );
    });

    test('deadline must not be absurdly in the past', () {
      expect(
        TaskWorkflowRules.isValidDeadline(
          DateTime.now().add(const Duration(days: 7)),
        ),
        isTrue,
      );
    });
  });
}
