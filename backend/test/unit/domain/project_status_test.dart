import 'package:test/test.dart';
import 'package:fs_hub_backend/shared/domain/project_status.dart';

void main() {
  group('ProjectStatus', () {
    test('normalize maps legacy values to ENUM', () {
      expect(ProjectStatus.normalize('Planifié'), ProjectStatus.aVenir);
      expect(ProjectStatus.normalize('Termine'), ProjectStatus.termine);
      expect(ProjectStatus.normalize('En retard'), ProjectStatus.suspendu);
      expect(ProjectStatus.normalize('Active'), ProjectStatus.enCours);
    });

    test('validate accepts canonical values only', () {
      expect(ProjectStatus.validate('En cours'), ProjectStatus.enCours);
      expect(
        () => ProjectStatus.validate('InvalidStatus'),
        throwsA(isA<Exception>()),
      );
    });

    test('all contains exactly four canonical statuses', () {
      expect(ProjectStatus.all, hasLength(4));
    });
  });
}
