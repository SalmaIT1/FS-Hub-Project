/// HR leave workflow rules (unit-testable).
class LeaveBusinessRules {
  LeaveBusinessRules._();

  /// Returns true when [start, end] overlaps any existing approved/pending leave.
  static bool hasDateOverlap({
    required DateTime start,
    required DateTime end,
    required List<DateRange> existing,
  }) {
    if (end.isBefore(start)) return true;
    for (final range in existing) {
      if (_rangesOverlap(start, end, range.start, range.end)) {
        return true;
      }
    }
    return false;
  }

  static bool _rangesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) =>
      !aEnd.isBefore(bStart) && !bEnd.isBefore(aStart);

  /// Paid leave quota: used + requested must not exceed annual allowance.
  static bool exceedsPaidQuota({
    required int requestedDays,
    required int usedDaysThisYear,
    required int annualQuota,
  }) =>
      usedDaysThisYear + requestedDays > annualQuota;

  static int remainingPaidQuota({
    required int usedDaysThisYear,
    required int annualQuota,
  }) =>
      (annualQuota - usedDaysThisYear).clamp(0, annualQuota);

  /// Self-approval is forbidden for leave requests.
  static bool isSelfApproval({
    required String requesterId,
    required String approverId,
  }) =>
      requesterId == approverId;
}

class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange({required this.start, required this.end});
}
