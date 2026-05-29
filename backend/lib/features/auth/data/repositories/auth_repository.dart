import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/database/connection.dart';
import '../../domain/repositories/auth_repository_port.dart';
import '../models/user_model.dart';

class AuthRepository implements AuthRepositoryPort {
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
    final userId = row.colByName('id')?.toString();
    final permissions = await getUserPermissions(userId ?? '');

    return {
      'id': userId,
      'username': row.colByName('username'),
      'password': row.colByName('password'),
      'role': row.colByName('role'),
      'matricule': row.colByName('matricule'),
      'nom': row.colByName('nom'),
      'prenom': row.colByName('prenom'),
      'email': row.colByName('email'),
      'permissions': permissions,
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
        'UPDATE refresh_tokens SET revoked = TRUE, updated_at = NOW() WHERE token = :token',
        {'token': token});
  }



  Future<void> addToTokenBlocklist(String token) async {
    final hash = sha256.convert(utf8.encode(token)).toString();
    await _db.execute(
        'INSERT IGNORE INTO revoked_tokens (token_hash) VALUES (:hash)',
        {'hash': hash});
  }

  Future<bool> isTokenInBlocklist(String token) async {
    final hash = sha256.convert(utf8.encode(token)).toString();
    final res = await _db.execute(
        'SELECT 1 FROM revoked_tokens WHERE token_hash = :hash',
        {'hash': hash});
    return res.rows.isNotEmpty;
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
        'revoked': row.colByName('revoked') == '1' || row.colByName('revoked') == 'true',
        'updated_at': row.colByName('updated_at')?.toString(),
      };
    });
  }

  Future<UserModel?> getProfile(String userId) async {
    final result = await _db.execute(
      '''SELECT u.id, u.username, u.role, u.permissions, u.dernierLogin,
                IFNULL(e.matricule, CAST(c.id AS CHAR)) as matricule, 
                IFNULL(e.nom, c.nom) as nom, 
                IFNULL(e.prenom, c.prenom) as prenom, 
                IFNULL(e.email, c.email) as email,
                e.poste, e.departement,
                c.raison_sociale, c.telephone as client_phone, c.adresse as client_adresse,
                c.matricule_fiscale, c.type, c.score_credit
         FROM users u 
         LEFT JOIN employees e ON u.id = e.user_id 
         LEFT JOIN clients c ON u.id = c.user_id
         WHERE u.id = :userId''',
      {'userId': userId},
    );

    if (result.rows.isEmpty) return null;

    final row = result.rows.first;
    final permissions = await getUserPermissions(userId);

    return UserModel.fromMap({
      'id': row.colByName('id'),
      'username': row.colByName('username'),
      'role': row.colByName('role'),
      'permissions': permissions,
      'dernierLogin': row.colByName('dernierLogin'),
      'matricule': row.colByName('matricule'),
      'nom': row.colByName('nom'),
      'prenom': row.colByName('prenom'),
      'email': row.colByName('email'),
      'poste': row.colByName('poste'),
      'departement': row.colByName('departement'),
      'raison_sociale': row.colByName('raison_sociale'),
      'client_phone': row.colByName('client_phone'),
      'client_adresse': row.colByName('client_adresse'),
      'matricule_fiscale': row.colByName('matricule_fiscale'),
      'type': row.colByName('type'),
      'score_credit': row.colByName('score_credit'),
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

  Future<String?> getPasswordHash(String userId) async {
    final result = await _db.execute(
      'SELECT password FROM users WHERE id = :userId',
      {'userId': userId},
    );
    if (result.rows.isEmpty) return null;
    return result.rows.first.colByName('password')?.toString();
  }

  Future<void> updatePassword(String userId, String newHash) async {
    await _db.execute(
      'UPDATE users SET password = :password WHERE id = :userId',
      {'password': newHash, 'userId': userId},
    );
  }

  Future<Map<String, dynamic>?> getUserSettings(String userId) async {
    final result = await _db.execute(
      'SELECT profile_visible, show_online_status, analytics_enabled FROM users WHERE id = :userId',
      {'userId': userId},
    );
    if (result.rows.isEmpty) return null;
    final row = result.rows.first;
    return {
      'profile_visible': row.colByName('profile_visible') == '1' || row.colByName('profile_visible') == 'true',
      'show_online_status': row.colByName('show_online_status') == '1' || row.colByName('show_online_status') == 'true',
      'analytics_enabled': row.colByName('analytics_enabled') == '1' || row.colByName('analytics_enabled') == 'true',
    };
  }

  Future<void> updateUserSettings(String userId, Map<String, dynamic> settings) async {
    await _db.execute(
      '''UPDATE users SET 
         profile_visible = :profile_visible, 
         show_online_status = :show_online_status, 
         analytics_enabled = :analytics_enabled 
         WHERE id = :userId''',
      {
        'profile_visible': settings['profile_visible'],
        'show_online_status': settings['show_online_status'],
        'analytics_enabled': settings['analytics_enabled'],
        'userId': userId,
      },
    );
  }

  Future<List<String>> getUserPermissions(String userId) async {
    try {
      // 1. Fetch all permissions associated with the user's role and direct permissions
      // We join roles and permissions to get the full list in one pass where possible.
      final result = await _db.execute('''
        SELECT DISTINCT p.nom
        FROM permissions p
        INNER JOIN role_permissions rp ON p.id = rp.permission_id
        INNER JOIN user_roles ur ON rp.role_id = ur.role_id
        WHERE ur.user_id = :userId

        UNION

        SELECT DISTINCT p.nom
        FROM permissions p
        JOIN role_permissions rp ON p.id = rp.permission_id
        JOIN roles r ON rp.role_id = r.id
        JOIN users u ON LOWER(r.nom) = LOWER(u.role)
        WHERE u.id = :userId

        UNION

        -- Direct permissions from string field (legacy support)
        SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(u.permissions, ',', n.n), ',', -1)) as nom
        FROM users u
        CROSS JOIN (
          SELECT a.N + b.N * 10 + 1 n
          FROM (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
          CROSS JOIN (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
        ) n
        WHERE u.id = :userId
        AND n.n <= 1 + (LENGTH(u.permissions) - LENGTH(REPLACE(u.permissions, ',', '')))
        AND u.permissions IS NOT NULL AND u.permissions != ''
      ''', {'userId': userId});
      
      return result.rows
          .map((r) => r.colAt(0).toString())
          .where((p) => p.isNotEmpty)
          .toList();
    } catch (e) {
      print('[AuthRepo] Critical permission load failure for $userId: $e');
      return [];
    }
  }

  /// HARSH FIX: Password Reset Tokens
  Future<void> savePasswordResetToken({
    required String userId,
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    // FIX: Using FROM_UNIXTIME to match TIMESTAMP column type.
    await _db.execute(
      'INSERT INTO password_resets (user_id, token_hash, expires_at) VALUES (:userId, :hash, FROM_UNIXTIME(:expires))',
      {
        'userId': userId,
        'hash': tokenHash,
        'expires': (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
      },
    );
  }

  Future<Map<String, dynamic>?> getResetTokenInfo(String tokenHash) async {
    final res = await _db.execute(
      'SELECT user_id, is_used, expires_at FROM password_resets WHERE token_hash = :hash',
      {'hash': tokenHash},
    );
    if (res.rows.isEmpty) return null;
    final row = res.rows.first;
    return {
      'user_id': row.colByName('user_id'),
      'is_used': row.colByName('is_used') == '1' || row.colByName('is_used') == 'true',
      'expires_at': row.colByName('expires_at')?.toString(),
    };
  }

  Future<void> markResetTokenUsed(String tokenHash) async {
    await _db.execute(
      'UPDATE password_resets SET is_used = TRUE WHERE token_hash = :hash',
      {'hash': tokenHash},
    );
  }

  Future<String> createUser({
    required String username,
    required String password,
    required String role,
    String? id,
  }) async {
    final userId = id ?? const Uuid().v4();
    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
    
    await _db.execute(
      '''INSERT INTO users (id, username, password, role) 
         VALUES (:id, :username, :password, :role)''',
      {
        'id': userId,
        'username': username,
        'password': hashedPassword,
        'role': role,
      },
    );
    return userId;
  }
}
