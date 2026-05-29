import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:fs_hub_backend/features/hr/domain/services/hr_service.dart';
import '../../mocks/repository_mocks.dart';

void main() {
  late MockHrRepository hrRepo;

  setUpAll(registerRepositoryFallbacks);

  setUp(() {
    hrRepo = MockHrRepository();
    HrService.bindForTest(hr: hrRepo);
  });

  tearDown(HrService.resetBindings);

  group('HrService.submitLeaveRequest', () {
    test('submits unpaid leave successfully', () async {
      when(() => hrRepo.submitLeaveRequest(any())).thenAnswer((_) async {});

      final result = await HrService.submitLeaveRequest('emp-1', {
        'leave_type': 'unpaid_leave',
        'start_date': '2026-07-01',
        'end_date': '2026-07-03',
        'total_days': 3,
      });

      expect(result['success'], isTrue);
      verify(() => hrRepo.submitLeaveRequest(any())).called(1);
    });

    test('rejects paid leave when quota exceeded', () async {
      when(() => hrRepo.getUsedPaidLeaveDaysInYear('emp-1', 2026))
          .thenAnswer((_) async => 20);

      final result = await HrService.submitLeaveRequest('emp-1', {
        'leave_type': 'paid_leave',
        'start_date': '2026-07-01',
        'end_date': '2026-07-05',
        'total_days': 5,
      });

      expect(result['success'], isFalse);
      expect(result['message'], contains('quota exceeded'));
      verifyNever(() => hrRepo.submitLeaveRequest(any()));
    });

    test('allows paid leave within quota', () async {
      when(() => hrRepo.getUsedPaidLeaveDaysInYear('emp-1', 2026))
          .thenAnswer((_) async => 10);
      when(() => hrRepo.submitLeaveRequest(any())).thenAnswer((_) async {});

      final result = await HrService.submitLeaveRequest('emp-1', {
        'leave_type': 'paid_leave',
        'start_date': '2026-07-01',
        'end_date': '2026-07-03',
        'total_days': 3,
      });

      expect(result['success'], isTrue);
      verify(() => hrRepo.submitLeaveRequest(any())).called(1);
    });

    test('rejects missing required fields', () async {
      final result = await HrService.submitLeaveRequest('emp-1', {
        'leave_type': 'paid_leave',
      });

      expect(result['success'], isFalse);
      verifyNever(() => hrRepo.submitLeaveRequest(any()));
    });
  });

  group('HrService.updateLeaveStatus', () {
    test('blocks self-approval', () async {
      when(() => hrRepo.getLeaveRequestEmployeeId(42))
          .thenAnswer((_) async => 'mgr-1');

      final result =
          await HrService.updateLeaveStatus(42, 'approved', 'mgr-1');

      expect(result['success'], isFalse);
      expect(result['message'], contains('own leave'));
      verifyNever(() => hrRepo.updateLeaveStatus(any(), any(), any()));
    });

    test('approves when approver differs from requester', () async {
      when(() => hrRepo.getLeaveRequestEmployeeId(42))
          .thenAnswer((_) async => 'emp-1');
      when(() => hrRepo.updateLeaveStatus(42, 'approved', 'mgr-1'))
          .thenAnswer((_) async {});

      final result =
          await HrService.updateLeaveStatus(42, 'approved', 'mgr-1');

      expect(result['success'], isTrue);
      verify(() => hrRepo.updateLeaveStatus(42, 'approved', 'mgr-1')).called(1);
    });
  });
}
