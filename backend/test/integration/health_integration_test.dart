@Tags(['integration'])
library fs_hub_integration_health;

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

  test('GET /healthz returns ok when DB is up', () async {
    final response = await harness.request('GET', '/healthz');
    await harness.expectStatus(response, 200);
    final body = await harness.jsonBody(response);
    expect(body['status'], 'ok');
    expect(body['db'], 'connected');
  });
}
