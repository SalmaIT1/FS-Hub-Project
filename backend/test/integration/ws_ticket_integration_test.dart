@Tags(['integration'])
library fs_hub_integration_ws_ticket;

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

  test('POST /v1/auth/ws-ticket returns one-time ticket', () async {
    final response = await harness.request(
      'POST',
      '/v1/auth/ws-ticket',
      headers: {'Authorization': 'Bearer $adminToken'},
    );
    await harness.expectStatus(response, 200);
    final body = await harness.jsonBody(response);
    expect(body['success'], isTrue);
    final ticket = body['ticket'] as String?;
    expect(ticket, isNotEmpty);

    final second = await harness.request(
      'POST',
      '/v1/auth/ws-ticket',
      headers: {'Authorization': 'Bearer $adminToken'},
    );
    await harness.expectStatus(second, 200);
    final ticket2 = (await harness.jsonBody(second))['ticket'] as String?;
    expect(ticket2, isNot(equals(ticket)));
  });

  test('GET /ws without ticket returns 401', () async {
    final response = await harness.request('GET', '/ws');
    await harness.expectStatus(response, 401);
  });
}
