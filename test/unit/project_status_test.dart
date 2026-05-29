import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/shared/models/project_status.dart';

void main() {
  group('ProjectStatus (Flutter)', () {
    test('normalize maps legacy API values', () {
      expect(ProjectStatus.normalize('Planifié'), ProjectStatus.aVenir);
      expect(ProjectStatus.normalize('Termine'), ProjectStatus.termine);
      expect(ProjectStatus.normalize('En retard'), ProjectStatus.suspendu);
    });

    test('labelsFr covers all canonical statuses', () {
      for (final status in ProjectStatus.all) {
        expect(ProjectStatus.labelsFr[status], isNotEmpty);
      }
    });
  });
}
