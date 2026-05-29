@Tags(['integration'])
library fs_hub_integration_security;

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

  group('Finance RBAC', () {
    test('GET /v1/finance/invoices without token returns 401', () async {
      final response = await harness.request('GET', '/v1/finance/invoices');
      await harness.expectStatus(response, 401);
    });

    test('POST /v1/finance/invoices with invalid token returns 401', () async {
      final response = await harness.request(
        'POST',
        '/v1/finance/invoices',
        headers: {'Authorization': 'Bearer invalid-token'},
        body: {'type': 'INVOICE'},
      );
      await harness.expectStatus(response, 401);
    });
  });
}
