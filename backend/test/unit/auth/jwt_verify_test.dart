import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';

void main() {
  group('AuthService.verifyToken — JWT', () {
    const secret = 'test-jwt-secret-for-unit-tests-only-32chars';

    setUpAll(() {
      // ignore: invalid_use_of_visible_for_testing_member
      AuthService.initSecretForTests(secret);
    });

    test('valid token returns payload', () {
      final token = JWT({
        'userId': 'user-1',
        'role': 'Admin',
        'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      }).sign(SecretKey(secret));

      final payload = AuthService.verifyToken(token);
      expect(payload?['userId'], 'user-1');
      expect(payload?['role'], 'Admin');
    });

    test('expired token returns null', () {
      final token = JWT({
        'userId': 'user-1',
        'role': 'Admin',
        'exp': DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      }).sign(SecretKey(secret));

      expect(AuthService.verifyToken(token), isNull);
    });

    test('tampered token returns null', () {
      final token = JWT({'userId': 'user-1', 'role': 'Admin'})
          .sign(SecretKey('wrong-secret'));
      expect(AuthService.verifyToken(token), isNull);
    });
  });
}
