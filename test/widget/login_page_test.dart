import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/features/auth/presentation/pages/login_page.dart';
import 'package:fs_hub/shared/widgets/glass_button.dart';

void main() {
  Widget buildTestApp() {
    return ChangeNotifierProvider(
      create: (_) => SettingsController(),
      child: const MaterialApp(home: GlassLoginPage()),
    );
  }

  group('GlassLoginPage widget', () {
    testWidgets('renders login form fields', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('(NGROK VERSION)'), findsOneWidget);
    });

    testWidgets('shows validation when submitting empty form', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GlassButton));
      await tester.pump();

      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('password visibility toggle', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });
}
