@Tags(['integration'])
library fs_hub_integration_finance;

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

  group('POST /v1/finance/invoices', () {
    test('creates invoice with valid timbre', () async {
      final numero =
          'INT-FAC-${DateTime.now().millisecondsSinceEpoch}';
      final response = await harness.request(
        'POST',
        '/v1/finance/invoices',
        headers: {
          'Authorization': 'Bearer $adminToken',
          'X-Idempotency-Key': 'inv-$numero',
        },
        body: {
          'type': 'INVOICE',
          'numero_facture': numero,
          'montant_ht': 1000,
          'tva': 190,
          'timbre': 1,
          'montant_ttc': 1191,
          'date_emission': '2026-05-24',
          'date_echeance': '2026-06-24',
          'statut': 'Brouillon',
        },
      );
      await harness.expectStatus(response, 201);
      final body = await harness.jsonBody(response);
      expect(body['success'], isTrue);
    });

    test('rejects invoice without mandatory timbre', () async {
      final response = await harness.request(
        'POST',
        '/v1/finance/invoices',
        headers: {'Authorization': 'Bearer $adminToken'},
        body: {
          'type': 'INVOICE',
          'numero_facture': 'INT-FAC-BAD-${DateTime.now().millisecondsSinceEpoch}',
          'montant_ht': 100,
          'tva': 19,
          'timbre': 0,
          'montant_ttc': 119,
        },
      );
      await harness.expectStatus(response, 400);
      final body = await harness.jsonBody(response);
      expect(body['success'], isFalse);
    });
  });
}
