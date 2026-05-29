abstract class AuthRepositoryPort {
  Future<Map<String, dynamic>?> findUserByUsernameOrEmail(String username);
  Future<void> updateLastLogin(String userId);
  Future<void> saveRefreshToken({
    required String userId,
    required String token,
    required DateTime expiresAt,
  });
}
