import 'package:test/test.dart';
import 'package:fs_hub_backend/shared/domain/leave_business_rules.dart';

void main() {
  group('LeaveBusinessRules — create leave request', () {
    test('detects overlapping leave periods', () {
      final existing = [
        DateRange(
          start: DateTime(2026, 6, 10),
          end: DateTime(2026, 6, 15),
        ),
      ];
      expect(
        LeaveBusinessRules.hasDateOverlap(
          start: DateTime(2026, 6, 12),
          end: DateTime(2026, 6, 14),
          existing: existing,
        ),
        isTrue,
      );
      expect(
        LeaveBusinessRules.hasDateOverlap(
          start: DateTime(2026, 6, 20),
          end: DateTime(2026, 6, 22),
          existing: existing,
        ),
        isFalse,
      );
    });

    test('paid leave quota exceeded', () {
      expect(
        LeaveBusinessRules.exceedsPaidQuota(
          requestedDays: 5,
          usedDaysThisYear: 20,
          annualQuota: 22,
        ),
        isTrue,
      );
      expect(
        LeaveBusinessRules.remainingPaidQuota(
          usedDaysThisYear: 18,
          annualQuota: 22,
        ),
        4,
      );
    });

    test('self-approval is forbidden', () {
      expect(
        LeaveBusinessRules.isSelfApproval(
          requesterId: 'emp-1',
          approverId: 'emp-1',
        ),
        isTrue,
      );
      expect(
        LeaveBusinessRules.isSelfApproval(
          requesterId: 'emp-1',
          approverId: 'mgr-1',
        ),
        isFalse,
      );
    });
  });
}
