/// E2E / integration_test configuration (read from `--dart-define` and env).
class E2eConfig {
  E2eConfig._();

  static const _runFlag = String.fromEnvironment('RUN_E2E_TESTS', defaultValue: '');

  /// Set `RUN_E2E_TESTS=true` or pass `--dart-define=RUN_E2E_TESTS=true`.
  static bool get enabled => _runFlag == 'true';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  static const adminUsername = String.fromEnvironment(
    'E2E_ADMIN_USER',
    defaultValue: 'admin',
  );

  static const adminPassword = String.fromEnvironment(
    'E2E_ADMIN_PASSWORD',
    defaultValue: '@ForeverSoftware2026',
  );
}
