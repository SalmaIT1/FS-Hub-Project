import 'package:bcrypt/bcrypt.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';
import '../../mocks/repository_mocks.dart';

void main() {
  late MockAuthRepository authRepo;

  setUpAll(() {
    registerRepositoryFallbacks();
    AuthService.initSecretForTests('test-jwt-secret-for-unit-tests-only-32chars');
  });

  setUp(() {
    authRepo = MockAuthRepository();
    AuthService.bindForTest(auth: authRepo);
  });

  tearDown(AuthService.resetBindings);

  group('AuthService.login', () {
    test('returns tokens for valid credentials', () async {
      final hash = BCrypt.hashpw('ValidP@ss1', BCrypt.gensalt());
      when(() => authRepo.findUserByUsernameOrEmail('admin'))
          .thenAnswer((_) async => {
                'id': 'user-1',
                'username': 'admin',
                'password': hash,
                'role': 'Admin',
                'permissions': ['manage_users'],
              });
      when(() => authRepo.updateLastLogin('user-1')).thenAnswer((_) async {});
      when(() => authRepo.saveRefreshToken(
            userId: any(named: 'userId'),
            token: any(named: 'token'),
            expiresAt: any(named: 'expiresAt'),
          )).thenAnswer((_) async {});

      final result = await AuthService.login('admin', 'ValidP@ss1');

      expect(result['success'], isTrue);
      expect(result['data'], isNotNull);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['accessToken'], isNotEmpty);
      expect(data['refreshToken'], isNotEmpty);
      verify(() => authRepo.updateLastLogin('user-1')).called(1);
    });

    test('rejects unknown user without leaking existence', () async {
      when(() => authRepo.findUserByUsernameOrEmail(any()))
          .thenAnswer((_) async => null);

      final result = await AuthService.login('ghost', 'any');

      expect(result['success'], isFalse);
      expect(result['message'], 'Invalid credentials');
      verifyNever(() => authRepo.updateLastLogin(any()));
    });

    test('rejects wrong password', () async {
      final hash = BCrypt.hashpw('CorrectP@ss1', BCrypt.gensalt());
      when(() => authRepo.findUserByUsernameOrEmail('user'))
          .thenAnswer((_) async => {
                'id': 'user-2',
                'username': 'user',
                'password': hash,
                'role': 'Employé',
              });

      final result = await AuthService.login('user', 'WrongP@ss1');

      expect(result['success'], isFalse);
      expect(result['message'], 'Invalid credentials');
    });

    test('rejects legacy plaintext password storage', () async {
      when(() => authRepo.findUserByUsernameOrEmail('legacy'))
          .thenAnswer((_) async => {
                'id': 'user-3',
                'username': 'legacy',
                'password': 'plaintext-not-bcrypt',
                'role': 'Employé',
              });

      final result = await AuthService.login('legacy', 'plaintext-not-bcrypt');

      expect(result['success'], isFalse);
      expect(result['message'], 'Invalid credentials');
    });
  });
}
