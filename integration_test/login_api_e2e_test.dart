import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/shared/widgets/glass_button.dart';
import 'package:fs_hub/shared/widgets/layout/main_layout.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_app.dart';
import 'support/e2e_auth.dart';
import 'support/e2e_config.dart';

void main() {
  if (!E2eConfig.enabled) {
    test(
      'API E2E skipped',
      () {},
      skip: 'Set RUN_E2E_TESTS=true and start backend on ${E2eConfig.apiBaseUrl}',
    );
    return;
  }

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await E2eApp.prepare();
    await resetE2eAuthState();
  });

  testWidgets('admin can log in and reach home shell', (tester) async {
    final reachable = await isBackendReachable();
    if (!reachable) {
      fail(
        'Backend not reachable at ${E2eConfig.apiBaseUrl}. '
        'Start the server and MySQL/Redis first.',
      );
    }

    await tester.pumpWidget(const E2eApp());
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, E2eConfig.adminUsername);
    await tester.enterText(fields.last, E2eConfig.adminPassword);
    await tester.tap(find.byType(GlassButton));
    await tester.pumpAndSettle(const Duration(seconds: 15));

    expect(find.byType(MainLayout), findsOneWidget);
  });
}
