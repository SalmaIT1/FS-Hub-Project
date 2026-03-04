import '../../../../shared/database/connection.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _db = DBConnection.getConnection();

  Future<Map<String, dynamic>?> findUserByUsernameOrEmail(String username) async {
    final result = await _db.execute(
      '''SELECT u.id, u.username, u.password, u.role, u.permissions, u.dernierLogin,
                e.matricule, e.nom, e.prenom, e.email
         FROM users u 
         LEFT JOIN employees e ON u.id = e.user_id 
         WHERE u.username = :username OR e.email = :username''',
      {'username': username},
    );

    if (result.rows.isEmpty) return null;

    final row = result.rows.first;
    return {
      'id': row.colByName('id')?.toString(),
      'username': row.colByName('username'),
      'password': row.colByName('password'),
      'role': row.colByName('role'),
      'matricule': row.colByName('matricule'),
      'nom': row.colByName('nom'),
      'prenom': row.colByName('prenom'),
      'email': row.colByName('email'),
    };
  }

  Future<void> updateLastLogin(String userId) async {
    await _db.execute(
      'UPDATE users SET dernierLogin = NOW() WHERE id = :userId',
      {'userId': userId},
    );
  }

  Future<void> saveRefreshToken({
    required String userId,
    required String token,
    required DateTime expiresAt,
  }) async {
    await _db.execute(
      'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (:userId, :token, FROM_UNIXTIME(:exp))',
      {
        'userId': userId,
        'token': token,
        'exp': (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
      },
    );
  }

  Future<void> revokeAllUserRefreshTokens(String userId) async {
    await _db.execute(
      'UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = :userId',
      {'userId': userId},
    );
  }

  Future<void> revokeRefreshToken(String token) async {
    await _db.execute(
      'UPDATE refresh_tokens SET revoked = TRUE WHERE token = :token',
      {'token': token},
    );
  }

  Future<Map<String, dynamic>?> getRefreshTokenInfo(String token, String userId) async {
    return await _db.transaction<Map<String, dynamic>?>((tx) async {
      final rows = await tx.execute(
        'SELECT id, revoked, updated_at FROM refresh_tokens WHERE token = :token AND user_id = :userId FOR UPDATE',
        {'token': token, 'userId': userId},
      );

      if (rows.rows.isEmpty) return null;

      final row = rows.rows.first;
      return {
        'revoked': row.colByName('revoked') == 1 || row.colByName('revoked') == true,
        'updated_at': row.colByName('updated_at')?.toString(),
      };
    });
  }

  Future<UserModel?> getProfile(String userId) async {
    final result = await _db.execute(
      '''SELECT u.id, u.username, u.role, u.permissions, u.dernierLogin,
                e.matricule, e.nom, e.prenom, e.email, e.poste, e.departement
         FROM users u 
         LEFT JOIN employees e ON u.id = e.user_id 
         WHERE u.id = :userId''',
      {'userId': userId},
    );

    if (result.rows.isEmpty) return null;

    final row = result.rows.first;
    return UserModel.fromMap({
      'id': row.colByName('id'),
      'username': row.colByName('username'),
      'role': row.colByName('role'),
      'permissions': row.colByName('permissions'),
      'dernierLogin': row.colByName('dernierLogin'),
      'matricule': row.colByName('matricule'),
      'nom': row.colByName('nom'),
      'prenom': row.colByName('prenom'),
      'email': row.colByName('email'),
      'poste': row.colByName('poste'),
      'departement': row.colByName('departement'),
    });
  }

  Future<String?> getUserRole(String userId) async {
    final res = await _db.execute(
      'SELECT role FROM users WHERE id = :userId',
      {'userId': userId},
    );
    if (res.rows.isEmpty) return null;
    return res.rows.first.colByName('role')?.toString();
  }
}
