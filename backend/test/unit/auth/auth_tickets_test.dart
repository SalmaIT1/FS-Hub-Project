import 'package:test/test.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';

void main() {
  group('AuthService — WS / media / payslip tickets', () {
    test('WS ticket is one-time use', () {
      final ticket = AuthService.issueWsTicket('user-42', 'Manager');
      final consumed = AuthService.consumeWsTicket(ticket);
      expect(consumed?['userId'], 'user-42');
      expect(consumed?['role'], 'Manager');
      expect(AuthService.consumeWsTicket(ticket), isNull);
    });

    test('media ticket scoped to filename', () {
      final ticket = AuthService.issueMediaTicket(
        userId: 'u1',
        role: 'Employé',
        storedFilename: 'photo.jpg',
      );
      expect(
        AuthService.consumeMediaTicket(ticket, 'photo.jpg')?['userId'],
        'u1',
      );
      expect(AuthService.consumeMediaTicket(ticket, 'other.jpg'), isNull);
    });

    test('payslip ticket scoped to salary id', () {
      final ticket = AuthService.issuePayslipTicket(
        userId: 'u1',
        role: 'RH',
        salaryId: 99,
      );
      expect(
        AuthService.consumePayslipTicket(ticket, 99)?['userId'],
        'u1',
      );
      expect(AuthService.consumePayslipTicket(ticket, 100), isNull);
    });

    test('invalid ticket returns null', () {
      expect(AuthService.consumeWsTicket('not-a-real-ticket'), isNull);
    });
  });
}
