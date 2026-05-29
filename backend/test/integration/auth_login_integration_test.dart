@Tags(['integration'])
library fs_hub_integration_auth;

import 'package:test/test.dart';

import 'integration_config.dart';
import 'integration_harness.dart';

void main() {
  if (!IntegrationConfig.enabled) {
    test(
      'integration tests skipped',
      () {},
      skip: 'Set RUN_INTEGRATION_TESTS=true and start MySQL',
    );
    return;
  }

  late IntegrationHarness harness;

  setUpAll(() async {
    harness = await IntegrationHarness.start();
  });

  tearDownAll(() async {
    await IntegrationHarness.shutdown();
  });

  group('POST /v1/auth/login', () {
    test('returns JWT for valid admin credentials', () async {
      final response = await harness.request(
        'POST',
        '/v1/auth/login',
        body: {
          'username': IntegrationConfig.adminUsername,
          'password': IntegrationConfig.adminPassword,
        },
      );
      await harness.expectStatus(response, 200);
      final body = await harness.jsonBody(response);
      expect(body['success'], isTrue);
      expect(body['data'], isA<Map>());
      final token = (body['data'] as Map)['accessToken'];
      expect(token, isNotEmpty);
    });

    test('returns 401 for invalid password', () async {
      final response = await harness.request(
        'POST',
        '/v1/auth/login',
        body: {
          'username': IntegrationConfig.adminUsername,
          'password': 'wrong-password',
        },
      );
      await harness.expectStatus(response, 401);
      final body = await harness.jsonBody(response);
      expect(body['success'], isFalse);
    });

    test('returns 400 when credentials missing', () async {
      final response = await harness.request(
        'POST',
        '/v1/auth/login',
        body: {'username': 'admin'},
      );
      await harness.expectStatus(response, 400);
    });
  });

  group('GET /v1/auth/profile', () {
    test('requires Bearer token', () async {
      final response = await harness.request('GET', '/v1/auth/profile');
      await harness.expectStatus(response, 401);
    });

    test('returns profile for authenticated admin', () async {
      final token = await harness.loginAndGetToken();
      final response = await harness.request(
        'GET',
        '/v1/auth/profile',
        headers: {'Authorization': 'Bearer $token'},
      );
      await harness.expectStatus(response, 200);
      final body = await harness.jsonBody(response);
      expect(body['success'], isTrue);
    });
  });
}
