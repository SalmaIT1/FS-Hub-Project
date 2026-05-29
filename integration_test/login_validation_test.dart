import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/shared/widgets/glass_button.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2eApp.prepare();
  });

  testWidgets('login form validates empty credentials', (tester) async {
    await tester.pumpWidget(const E2eApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GlassButton));
    await tester.pump();

    expect(find.byType(Form), findsOneWidget);
    expect(find.text('admin'), findsNothing);
  });

  testWidgets('password visibility toggle works', (tester) async {
    await tester.pumpWidget(const E2eApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });
}
