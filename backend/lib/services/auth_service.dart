import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import '../database/db_connection.dart';
import 'package:mysql_client/mysql_client.dart';

class AuthService {
  // Secret is read from environment at runtime to avoid hardcoding secrets in code.
  static String _jwtSecret() {
    try {
      final d = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
      return d['JWT_SECRET'] ?? '';
    } catch (_) {
      return '';
    }
  }
  static const Duration _tokenExpiry = Duration(hours: 24);
  static const Duration _refreshTokenExpiry = Duration(days: 7);

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final conn = DBConnection.getConnection();
      
      // Query to get user by username or email
      final result = await conn.execute(
        '''SELECT u.id, u.username, u.password, u.role, u.permissions, u.dernierLogin,
                  e.matricule, e.nom, e.prenom, e.email
           FROM users u 
           LEFT JOIN employees e ON u.id = e.user_id 
           WHERE u.username = :username OR e.email = :username''',
        {
          'username': username,
        },
      );

      if (result.rows.isEmpty) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      final row = result.rows.first;
      final storedPassword = row.colByName('password') as String;
      final userId = row.colByName('id').toString();
      final userRole = row.colByName('role') as String?;
      final permissions = row.colByName('permissions') as String?;

      // Password comparison: legacy systems may store plaintext; prefer hashed.
      // If stored password appears to be a bcrypt hash (starts with "$2"),
      // production should verify accordingly. For backwards compatibility,
      // fall back to direct comparison when no hash is present.
      if (storedPassword.startsWith(r'$2')) {
        // bcrypt verification not implemented here to avoid adding libraries.
        // Treat as invalid and require migration if hash format detected but
        // no verifier is available.
        return {'success': false, 'message': 'Password verification not available for hashed passwords'};
      } else {
        if (password != storedPassword) {
          return {'success': false, 'message': 'Invalid credentials'};
        }
      }

      // Update last login
      await conn.execute(
        'UPDATE users SET dernierLogin = NOW() WHERE id = :userId',
        {'userId': userId},
      );

      // Generate tokens
      final accessToken = _generateAccessToken(userId, userRole ?? 'Employé');
      final refreshToken = _generateRefreshToken(userId);

      // Persist refresh token for revocation and validation
      try {
        await conn.execute('INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (:userId, :token, FROM_UNIXTIME(:exp))', {
          'userId': userId,
          'token': refreshToken,
          'exp': (DateTime.now().add(_refreshTokenExpiry).millisecondsSinceEpoch ~/ 1000).toString(),
        });
      } catch (e) {
        print('Failed to persist refresh token: $e');
      }

      return {
        'success': true,
        'message': 'Login successful',
        'data': {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'user': {
            'id': userId,
            'username': row.colByName('username'),
            'role': userRole,
            'matricule': row.colByName('matricule'),
            'nom': row.colByName('nom'),
            'prenom': row.colByName('prenom'),
            'email': row.colByName('email'),
          }
        }
      };
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Login failed'};
    }
  }

  static Future<Map<String, dynamic>> logout(String? token) async {
    try {
      if (token == null) return {'success': true, 'message': 'No token provided'};
      final payload = verifyToken(token);
      if (payload == null) return {'success': false, 'message': 'Invalid token'};
      final userId = payload['userId']?.toString();
      if (userId == null) return {'success': false, 'message': 'Invalid token payload'};

      final conn = DBConnection.getConnection();
      await conn.execute('UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = :userId', {'userId': userId});

      return {'success': true, 'message': 'Logged out successfully'};
    } catch (e) {
      print('Logout error: $e');
      return {'success': false, 'message': 'Logout failed'};
    }
  }

  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      // In a real implementation, you would validate the refresh token against stored tokens
      // For now, we'll just generate a new access token
      
      // Verify refresh token signature and expiry
      JWT jwt;
      try {
        jwt = JWT.verify(refreshToken, SecretKey(_jwtSecret()));
      } catch (e) {
        return {'success': false, 'message': 'Invalid refresh token'};
      }

      final userId = jwt.payload['userId']?.toString();
      if (userId == null) return {'success': false, 'message': 'Invalid refresh token payload'};

      // Ensure refresh token is persisted and not revoked. Use a transaction
      // with SELECT ... FOR UPDATE to avoid races when rotating tokens.
      return await DBConnection.getConnection().transaction<Map<String, dynamic>>((conn) async {
        final rows = await conn.execute('SELECT id, revoked, UNIX_TIMESTAMP(IFNULL(expires_at, NOW()+0)) as exp FROM refresh_tokens WHERE token = :token AND user_id = :userId FOR UPDATE', {'token': refreshToken, 'userId': userId});
        if (rows.rows.isEmpty) {
          return {'success': false, 'message': 'Refresh token not recognized'};
        }

        final row = rows.rows.first;
        final revoked = (row.colByName('revoked') == 1) || (row.colByName('revoked') == true);
        if (revoked) return {'success': false, 'message': 'Refresh token revoked'};

        // Get user's role
        final userRes = await conn.execute('SELECT role FROM users WHERE id = :userId', {'userId': userId});
        if (userRes.rows.isEmpty) return {'success': false, 'message': 'User not found'};
        final userRole = userRes.rows.first.colByName('role') as String?;

        final newAccessToken = _generateAccessToken(userId, userRole ?? 'Employé');
        final newRefreshToken = _generateRefreshToken(userId);

        // Revoke old token and persist new one in same transaction
        try {
          await conn.execute('UPDATE refresh_tokens SET revoked = TRUE WHERE token = :token', {'token': refreshToken});
          await conn.execute('INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (:userId, :token, FROM_UNIXTIME(:exp))', {
            'userId': userId,
            'token': newRefreshToken,
            'exp': (DateTime.now().add(_refreshTokenExpiry).millisecondsSinceEpoch ~/ 1000).toString(),
          });
        } catch (e) {
          print('Failed to rotate refresh token: $e');
          return {'success': false, 'message': 'Failed to rotate refresh token'};
        }

        return {
          'success': true,
          'message': 'Tokens refreshed successfully',
          'data': {
            'accessToken': newAccessToken,
            'refreshToken': newRefreshToken,
          }
        };
      });
    } catch (e) {
      print('Refresh token error: $e');
      return {'success': false, 'message': 'Failed to refresh token'};
    }
  }

  static Future<Map<String, dynamic>> getProfile(String? token) async {
    if (token == null) {
      return {'success': false, 'message': 'No token provided'};
    }

    try {
      // Verify token signature and expiry
      JWT jwt;
      try {
        jwt = JWT.verify(token, SecretKey(_jwtSecret()));
      } catch (e) {
        return {'success': false, 'message': 'Invalid token'};
      }

      final userId = jwt.payload['userId'] as String?;

      if (userId == null) {
        return {'success': false, 'message': 'Invalid token payload'};
      }

      final conn = DBConnection.getConnection();
      final result = await conn.execute(
        '''SELECT u.id, u.username, u.role, u.permissions, u.dernierLogin,
                  e.matricule, e.nom, e.prenom, e.email, e.poste, e.departement
           FROM users u 
           LEFT JOIN employees e ON u.id = e.user_id 
           WHERE u.id = :userId''',
        {'userId': userId},
      );

      if (result.rows.isEmpty) {
        return {'success': false, 'message': 'User not found'};
      }

      final row = result.rows.first;

      return {
        'success': true,
        'data': {
          'id': row.colByName('id'),
          'username': row.colByName('username'),
          'role': row.colByName('role'),
          'permissions': row.colByName('permissions'),
          'dernierLogin': row.colByName('dernierLogin')?.toString(),
          'matricule': row.colByName('matricule'),
          'nom': row.colByName('nom'),
          'prenom': row.colByName('prenom'),
          'email': row.colByName('email'),
          'poste': row.colByName('poste'),
          'departement': row.colByName('departement'),
        }
      };
    } catch (e) {
      print('Get profile error: $e');
      return {'success': false, 'message': 'Failed to get profile'};
    }
  }

  static String _generateAccessToken(String userId, String role) {
    final jwt = JWT({
      'userId': userId,
      'role': role,
      'exp': DateTime.now().add(_tokenExpiry).millisecondsSinceEpoch ~/ 1000,
    });

    return jwt.sign(SecretKey(_jwtSecret()));
  }

  static String _generateRefreshToken(String userId) {
    final jwt = JWT({
      'userId': userId,
      'type': 'refresh',
      'exp': DateTime.now().add(_refreshTokenExpiry).millisecondsSinceEpoch ~/ 1000,
    });

    return jwt.sign(SecretKey(_jwtSecret()));
  }

  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret()));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      print('Token verification error: $e');
      return null;
    }
  }
}