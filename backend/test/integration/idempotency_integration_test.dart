@Tags(['integration'])
library fs_hub_integration_idempotency;

import 'package:fs_hub_backend/core/services/redis_service.dart';
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
  late String adminToken;

  setUpAll(() async {
    harness = await IntegrationHarness.start();
    adminToken = await harness.loginAndGetToken();
  });

  tearDownAll(() async {
    await IntegrationHarness.shutdown();
  });

  test('duplicate X-Idempotency-Key on POST returns 409 when Redis is up', () async {
    await RedisService().initialize();
    final key = 'idem-${DateTime.now().millisecondsSinceEpoch}';
    final headers = {
      'Authorization': 'Bearer $adminToken',
      'X-Idempotency-Key': key,
    };
    final body = {
      'leave_type': 'unpaid_leave',
      'start_date': '2026-10-01',
      'end_date': '2026-10-02',
      'total_days': 2,
      'reason': 'integration-idempotency',
    };

    final first = await harness.request(
      'POST',
      '/v1/hr/leaves',
      headers: headers,
      body: body,
    );
    expect(first.statusCode, anyOf(200, 503));

    if (first.statusCode == 200) {
      final second = await harness.request(
        'POST',
        '/v1/hr/leaves',
        headers: headers,
        body: body,
      );
      await harness.expectStatus(second, 409);
    }
  });
}
