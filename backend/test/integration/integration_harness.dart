import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:fs_hub_backend/app/http_app.dart';
import 'package:fs_hub_backend/core/config/runtime_config.dart';
import 'package:fs_hub_backend/core/services/redis_service.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';
import 'package:fs_hub_backend/features/email/domain/services/email_service.dart';
import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:fs_hub_backend/shared/database/migrations.dart';
import 'package:shelf/shelf.dart';

import 'integration_config.dart';

/// Boots the full Shelf pipeline against a real MySQL instance.
class IntegrationHarness {
  IntegrationHarness._(this.handler);

  final Handler handler;

  static Future<IntegrationHarness> start() async {
    IntegrationConfig.applyTestEnvironment();

    if (!await Directory('uploads').exists()) {
      await Directory('uploads').create(recursive: true);
    }

    AuthService.initSecretForTests(IntegrationConfig.require('JWT_SECRET'));
    EmailService.initialize();
    await Migrations.initializeDatabase();
    await RedisService().initialize();
    await _seedIntegrationPermissions();

    final app = HttpApp(disableRateLimit: true);
    return IntegrationHarness._(app.createHandler(corsOrigin: 'http://localhost'));
  }

  static Future<void> _seedIntegrationPermissions() async {
    final db = DBConnection.getConnection();
    final perms = [
      'manage_invoices',
      'view_invoices',
      'manage_payments',
      'submit_leave',
      'manage_leaves',
      'manage_quotes',
      'view_quotes',
    ];
    for (final name in perms) {
      await db.execute(
        "INSERT IGNORE INTO permissions (nom, module, description) VALUES (:n, 'Test', 'Integration')",
        {'n': name},
      );
    }
    await db.execute('''
      INSERT IGNORE INTO role_permissions (role_id, permission_id)
      SELECT r.id, p.id FROM roles r, permissions p
      WHERE r.nom = 'Admin' AND p.nom IN (
        'manage_invoices','view_invoices','manage_payments',
        'submit_leave','manage_leaves','manage_quotes','view_quotes'
      )
    ''');

    const empId = 'integration-emp-001';
    final hash = BCrypt.hashpw('TestEmp@123', BCrypt.gensalt());
    await db.execute(
      '''INSERT IGNORE INTO users (id, username, password, role)
         VALUES (:id, 'integration_emp', :pw, 'Employé')''',
      {'id': empId, 'pw': hash},
    );
    await db.execute(
      '''INSERT IGNORE INTO employees (id, user_id, matricule, nom, prenom, email, poste, departement, statut)
         VALUES (:id, :id, 'INT-001', 'Integration', 'Employee', 'int@test.local', 'QA', 'IT', 'actif')''',
      {'id': empId},
    );
  }

  Future<Response> request(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse('http://localhost$path');
    final jsonBody = body != null ? jsonEncode(body) : null;
    final response = await handler(
      Request(
        method,
        uri,
        body: jsonBody,
        headers: {
          if (jsonBody != null) 'Content-Type': 'application/json',
          ...?headers,
        },
      ),
    );
    return response;
  }

  Future<Map<String, dynamic>> jsonBody(Response response) async {
    final raw = await response.readAsString();
    if (raw.isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<String> loginAndGetToken({
    String username = IntegrationConfig.adminUsername,
    String password = IntegrationConfig.adminPassword,
  }) async {
    final response = await request(
      'POST',
      '/v1/auth/login',
      body: {'username': username, 'password': password},
    );
    await expectStatus(response, 200);
    final data = await jsonBody(response);
    final session = data['data'] as Map<String, dynamic>;
    return session['accessToken'] as String;
  }

  Future<void> expectStatus(Response response, int expected) async {
    if (response.statusCode != expected) {
      final body = await response.readAsString();
      throw TestFailure(
        'Expected HTTP $expected but got ${response.statusCode}: $body',
      );
    }
  }

  static Future<void> shutdown() async {
    RuntimeConfig.clearOverrides();
    await DBConnection.close();
  }
}

class TestFailure implements Exception {
  TestFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
