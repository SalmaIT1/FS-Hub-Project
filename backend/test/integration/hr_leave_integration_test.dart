@Tags(['integration'])
library fs_hub_integration_hr;

import 'package:fs_hub_backend/shared/database/connection.dart';
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

  setUp(() async {
    final db = DBConnection.getConnection();
    await db.execute(
      "DELETE FROM leave_requests WHERE reason LIKE 'integration-%'",
    );
  });

  group('POST /v1/hr/leaves', () {
    test('submits leave request for authenticated user', () async {
      final response = await harness.request(
        'POST',
        '/v1/hr/leaves',
        headers: {
          'Authorization': 'Bearer $adminToken',
          'X-Idempotency-Key': 'leave-${DateTime.now().millisecondsSinceEpoch}',
        },
        body: {
          'leave_type': 'unpaid_leave',
          'start_date': '2026-08-01',
          'end_date': '2026-08-03',
          'total_days': 3,
          'reason': 'integration-unpaid-leave',
        },
      );
      await harness.expectStatus(response, 200);
      final body = await harness.jsonBody(response);
      expect(body['success'], isTrue);
    });

    test('rejects paid leave exceeding annual quota', () async {
      final db = DBConnection.getConnection();
      await db.execute(
        '''INSERT INTO leave_requests
           (employee_id, leave_type, start_date, end_date, total_days, reason, status)
           VALUES ('admin-uuid-001', 'paid_leave', '2026-01-02', '2026-01-22', 21, 'integration-fill', 'approved')''',
      );

      final response = await harness.request(
        'POST',
        '/v1/hr/leaves',
        headers: {'Authorization': 'Bearer $adminToken'},
        body: {
          'leave_type': 'paid_leave',
          'start_date': '2026-09-01',
          'end_date': '2026-09-05',
          'total_days': 3,
          'reason': 'integration-quota-exceeded',
        },
      );
      await harness.expectStatus(response, 400);
      final body = await harness.jsonBody(response);
      expect(body['success'], isFalse);
      expect(body['message'], contains('quota'));
    });
  });
}
