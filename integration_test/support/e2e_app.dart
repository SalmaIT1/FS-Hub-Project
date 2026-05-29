import 'package:flutter/material.dart';
import 'package:fs_hub/core/routes/app_routes.dart';
import 'package:fs_hub/core/security/permission_guard.dart';
import 'package:fs_hub/core/state/location_controller.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/core/theme/app_theme.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:fs_hub/features/auth/presentation/pages/login_page.dart';
import 'package:fs_hub/shared/widgets/layout/main_layout.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal app shell for E2E tests (no splash delay, no window_manager).
class E2eApp extends StatelessWidget {
  const E2eApp({super.key, this.initialRoute = AppRoutes.login});

  final String initialRoute;

  static Future<void> prepare() async {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PermissionGuard.resetForTest();
    await AuthService.logout();
    await AppTheme.init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => LocationController()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.glassLightTheme,
        darkTheme: AppTheme.glassDarkTheme,
        initialRoute: initialRoute,
        routes: {
          AppRoutes.login: (_) => const GlassLoginPage(),
          AppRoutes.home: (_) => const MainLayout(initialRoute: '/'),
        },
      ),
    );
  }
}
