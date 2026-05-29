import 'dart:io';

import 'package:fs_hub_backend/core/config/runtime_config.dart';

/// Integration tests require MySQL (and optionally Redis) — enable explicitly.
class IntegrationConfig {
  IntegrationConfig._();

  static bool get enabled =>
      Platform.environment['RUN_INTEGRATION_TESTS'] == 'true';

  /// Applies defaults; shell env and `.env.integration` can override.
  static void applyTestEnvironment() {
    final defaults = <String, String>{
      'DISABLE_RATE_LIMIT': 'true',
      'JWT_SECRET': 'integration-test-jwt-secret-min-32-chars-long',
      'DB_HOST': '127.0.0.1',
      'DB_PORT': '3307',
      'DB_USER': 'root',
      'DB_PASSWORD': 'test',
      'DB_NAME': 'fs_hub_test',
      'DB_SECURE': 'false',
      'REDIS_HOST': '127.0.0.1',
      'REDIS_PORT': '6380',
    };

    final merged = <String, String>{...defaults};
    for (final key in defaults.keys) {
      final fromShell = Platform.environment[key];
      if (fromShell != null && fromShell.isNotEmpty) {
        merged[key] = fromShell;
      }
    }

    RuntimeConfig.setOverrides(merged);
  }

  static String require(String key) {
    final value = RuntimeConfig.get(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing required integration env: $key');
    }
    return value;
  }

  /// Default admin from [DatabaseSeeder] when DB is empty.
  static const adminUsername = 'admin';
  static const adminPassword = '@ForeverSoftware2026';
}
