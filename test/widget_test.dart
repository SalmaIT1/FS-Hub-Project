import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/shared/models/project_status.dart';

/// Root smoke test — keeps `flutter test` green without loading full app shell.
void main() {
  test('FS-Hub test harness is wired', () {
    expect(ProjectStatus.all, isNotEmpty);
  });
}
