import 'package:test/test.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';

void main() {
  group('AuthService.validatePasswordComplexity — login / reset', () {
    test('rejects short passwords', () {
      expect(AuthService.validatePasswordComplexity('Ab1!'), isFalse);
    });

    test('rejects missing uppercase', () {
      expect(AuthService.validatePasswordComplexity('abcdef1!'), isFalse);
    });

    test('rejects missing special character', () {
      expect(AuthService.validatePasswordComplexity('Abcdef12'), isFalse);
    });

    test('accepts strong password', () {
      expect(AuthService.validatePasswordComplexity('SecureP@ss1'), isTrue);
    });
  });
}
