import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../database/db_connection.dart';
import 'package:mysql_client/mysql_client.dart';

class AuthService {
  static const String _jwtSecret = 'your_jwt_secret_key_here'; // Should be in environment variables
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

      // Simple password comparison (in production, use bcrypt or similar)
      if (password != storedPassword) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      // Update last login
      await conn.execute(
        'UPDATE users SET dernierLogin = NOW() WHERE id = :userId',
        {'userId': userId},
      );

      // Generate tokens
      final accessToken = _generateAccessToken(userId, userRole ?? 'Employé');
      final refreshToken = _generateRefreshToken(userId);

      // Store refresh token in database (in a real app, you'd have a refresh_tokens table)
      // For now, we'll just return it without storing

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
    // In a real implementation, you would invalidate the token
    // For now, we just return success
    return {'success': true, 'message': 'Logged out successfully'};
  }

  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      // In a real implementation, you would validate the refresh token against stored tokens
      // For now, we'll just generate a new access token
      
      // Decode the refresh token to get user ID
      final jwt = JWT.decode(refreshToken);
      final userId = jwt.payload['userId'] as String?;
      
      if (userId == null) {
        return {'success': false, 'message': 'Invalid refresh token'};
      }

      // Get user role from database
      final conn = DBConnection.getConnection();
      final result = await conn.execute(
        'SELECT role FROM users WHERE id = :userId',
        {'userId': userId},
      );

      if (result.rows.isEmpty) {
        return {'success': false, 'message': 'User not found'};
      }

      final userRole = result.rows.first.colByName('role') as String?;
      final newAccessToken = _generateAccessToken(userId, userRole ?? 'Employé');
      final newRefreshToken = _generateRefreshToken(userId);

      return {
        'success': true,
        'message': 'Tokens refreshed successfully',
        'data': {
          'accessToken': newAccessToken,
          'refreshToken': newRefreshToken,
        }
      };
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
      final jwt = JWT.decode(token);
      final userId = jwt.payload['userId'] as String?;
      
      if (userId == null) {
        return {'success': false, 'message': 'Invalid token'};
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

    return jwt.sign(SecretKey(_jwtSecret));
  }

  static String _generateRefreshToken(String userId) {
    final jwt = JWT({
      'userId': userId,
      'type': 'refresh',
      'exp': DateTime.now().add(_refreshTokenExpiry).millisecondsSinceEpoch ~/ 1000,
    });

    return jwt.sign(SecretKey(_jwtSecret));
  }

  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      print('Token verification error: $e');
      return null;
    }
  }
}