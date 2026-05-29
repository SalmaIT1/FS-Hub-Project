import 'dart:io';

/// Optional env overrides (integration tests). Production code ignores when empty.
class RuntimeConfig {
  RuntimeConfig._();

  static final Map<String, String> _overrides = {};

  static void setOverrides(Map<String, String> values) {
    _overrides
      ..clear()
      ..addAll(values);
  }

  static void clearOverrides() => _overrides.clear();

  static String? get(String key) =>
      _overrides[key] ?? Platform.environment[key];

  static bool get disableRateLimit => get('DISABLE_RATE_LIMIT') == 'true';
}
