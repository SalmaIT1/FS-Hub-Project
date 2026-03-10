import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:uuid/uuid.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';
import '../../data/models/auth_session_model.dart';
import 'dart:io';
import 'dart:math';
import '../../../email/domain/services/email_service.dart';
// Just in case it's needed for JSON and crypto.

class AuthService {
  static final _repository = AuthRepository();
  static String _secret = '';

  static void initSecret() {
    // Priority: Platform Environment > .env file
    String? s = Platform.environment['JWT_SECRET'];
    
    if (s == null || s.trim().isEmpty) {
      final d = dotenv.DotEnv(includePlatformEnvironment: true)..load(['.env']);
      s = d['JWT_SECRET'];
    }

    if (s == null || s.trim().isEmpty) {
      throw StateError(
          'FATAL: JWT_SECRET is not set in environment or .env. '
          'The server cannot start without a secure JWT secret.');
    }
    _secret = s.trim();
  }

  static const Duration _tokenExpiry = Duration(hours: 24);
  static const Duration _refreshTokenExpiry = Duration(days: 7);

  // ── Access-token revocation (in-memory blocklist) ────────────────────────
  // Stores tokens that have been explicitly logged out before their expiry.
  // Cleared on server restart — acceptable for dev/MVP. For production,
  // replace with a Redis-backed store.
  // No longer needed: replace with persistent DB store
  // static final Set<String> _revokedTokens = {};

  static void revokeAccessToken(String token) async {
    try {
      await _repository.addToTokenBlocklist(token);
    } catch (e) {
      print('Failed to persist token revocation: $e');
    }
  }

  static Future<bool> isTokenRevoked(String token) async {
    try {
       return await _repository.isTokenInBlocklist(token);
    } catch (e) {
      return false;
    }
  }

  // ── WS Ticket store (short-lived one-time tickets) ───────────────────────
  static final Map<String, _WsTicket> _wsTickets = {};

  static String issueWsTicket(String userId, String role) {
    // Clean up expired tickets first
    _wsTickets.removeWhere((_, t) => t.isExpired);

    final ticket = const Uuid().v4();
    _wsTickets[ticket] = _WsTicket(userId: userId, role: role);
    return ticket;
  }

  /// Validates and consumes a WS ticket (one-time use).
  static Map<String, String>? consumeWsTicket(String ticket) {
    final t = _wsTickets.remove(ticket);
    if (t == null || t.isExpired) return null;
    return {'userId': t.userId, 'role': t.role};
  }

  // ── Login ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final userRow = await _repository.findUserByUsernameOrEmail(username);

      if (userRow == null) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      final storedPassword = userRow['password'] as String;
      final userId = userRow['id'].toString();
      final userRole = userRow['role'] as String?;

      bool isValid = false;
      if (storedPassword.startsWith(r'$2')) {
        try {
          isValid = BCrypt.checkpw(password, storedPassword);
        } catch (e) {
          print('BCrypt check failed: $e');
        }
      } else {
        print('Warning: Attempted login with legacy password format for user ID: $userId');
        isValid = false;
      }

      if (!isValid) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      await _repository.updateLastLogin(userId);

      final accessToken = _generateAccessToken(userId, userRole ?? 'Employé');
      final refreshToken = _generateRefreshToken(userId);
      print('[DEBUG] Tokens generated for userId: $userId');

      try {
        await _repository.saveRefreshToken(
          userId: userId,
          token: refreshToken,
          expiresAt: DateTime.now().add(_refreshTokenExpiry),
        );
        print('[DEBUG] Refresh token saved');
      } catch (e) {
        print('Failed to persist refresh token: $e');
      }

      print('[DEBUG] Converting userRow to UserModel. userRow keys: ${userRow.keys}');
      print('[DEBUG] permissions type: ${userRow['permissions'].runtimeType}');
      
      final session = AuthSessionModel(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: UserModel.fromMap(userRow),
      );
      print('[DEBUG] Session created');

      return {
        'success': true,
        'message': 'Login successful',
        'data': session.toJson()
      };
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Login failed'};
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> logout(String? token) async {
    try {
      if (token == null) {
        return {'success': true, 'message': 'No token provided'};
      }

      // Revoke access token immediately.
      revokeAccessToken(token);

      final payload = verifyToken(token);
      if (payload == null) {
        return {'success': true, 'message': 'Logged out'};
      }

      final userId = payload['userId']?.toString();
      if (userId != null) {
        await _repository.revokeAllUserRefreshTokens(userId);
      }

      return {'success': true, 'message': 'Logged out successfully'};
    } catch (e) {
      print('Logout error: $e');
      return {'success': false, 'message': 'Logout failed'};
    }
  }

  // ── Refresh token ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> refreshToken(
      String refreshToken) async {
    try {
      JWT jwt;
      try {
        jwt = JWT.verify(refreshToken, SecretKey(_secret));
      } catch (e) {
        return {'success': false, 'message': 'Invalid refresh token'};
      }

      final userId = jwt.payload['userId']?.toString();
      if (userId == null) {
        return {'success': false, 'message': 'Invalid refresh token payload'};
      }

      final info = await _repository.getRefreshTokenInfo(refreshToken, userId);

      if (info == null) {
        return {'success': false, 'message': 'Refresh token not recognized'};
      }

      final revoked = info['revoked'] == true;
      if (revoked) {
        final updatedAtRaw = info['updated_at'];
        if (updatedAtRaw != null) {
          final updatedAt = DateTime.parse(updatedAtRaw.toString());
          if (DateTime.now().difference(updatedAt).inSeconds < 30) {
            return {
              'success': false,
              'message': 'Token recently refreshed. Please use new tokens.'
            };
          }
        }
        return {'success': false, 'message': 'Refresh token revoked'};
      }

      final userRole = await _repository.getUserRole(userId);
      if (userRole == null) {
        return {'success': false, 'message': 'User not found'};
      }

      final newAccessToken = _generateAccessToken(userId, userRole);
      final newRefreshToken = _generateRefreshToken(userId);

      await _repository.revokeRefreshToken(refreshToken);
      await _repository.saveRefreshToken(
        userId: userId,
        token: newRefreshToken,
        expiresAt: DateTime.now().add(_refreshTokenExpiry),
      );

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

  // ── Get Profile ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile(String? token) async {
    if (token == null) {
      return {'success': false, 'message': 'No token provided'};
    }
    try {
      JWT jwt;
      try {
        jwt = JWT.verify(token, SecretKey(_secret));
      } catch (e) {
        return {'success': false, 'message': 'Invalid token'};
      }

      final userId = jwt.payload['userId'] as String?;
      if (userId == null) {
        return {'success': false, 'message': 'Invalid token payload'};
      }

      final profile = await _repository.getProfile(userId);

      if (profile == null) {
        return {'success': false, 'message': 'User not found'};
      }

      return {
        'success': true,
        'data': profile.toJson()
      };
    } catch (e) {
      print('Get profile error: $e');
      return {'success': false, 'message': 'Failed to get profile'};
    }
  }

  // ── Change Password ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> changePassword(String userId, String oldPassword, String newPassword) async {
    try {
      final storedHash = await _repository.getPasswordHash(userId);
      if (storedHash == null) {
        return {'success': false, 'message': 'User not found'};
      }

      bool isValid = false;
      if (storedHash.startsWith(r'$2')) {
        isValid = BCrypt.checkpw(oldPassword, storedHash);
      }

      if (!isValid) {
        return {'success': false, 'message': 'Incorrect current password'};
      }

      final newHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
      await _repository.updatePassword(userId, newHash);
      return {'success': true, 'message': 'Password updated successfully'};
    } catch (e) {
      print('Change password error: $e');
      return {'success': false, 'message': 'Failed to update password'};
    }
  }

  // ── Forgot Password & Admin Reset ─────────────────────────────────────────

  /// Self-service forgot password. 
  /// In this flow, we generate a new password and send it to the user.
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final userRow = await _repository.findUserByUsernameOrEmail(email);
      if (userRow == null) {
        // For security, don't reveal if user exists, but we can't send email if not.
        // But for internal tool, we can be more explicit.
        return {'success': false, 'message': 'No account associated with this email'};
      }

      final userId = userRow['id'].toString();
      final userName = '${userRow['prenom'] ?? ''} ${userRow['nom'] ?? ''}'.trim();
      final userEmail = userRow['email'] as String?;

      if (userEmail == null || userEmail.isEmpty) {
        return {'success': false, 'message': 'Account has no associated email'};
      }

      final newPassword = _generateRandomPassword();
      final hashedUrl = BCrypt.hashpw(newPassword, BCrypt.gensalt());

      await _repository.updatePassword(userId, hashedUrl);

      final emailResult = await EmailService.sendPasswordResetEmail(
        userEmail: userEmail,
        userName: userName.isEmpty ? (userRow['username'] ?? 'User') : userName,
        newPassword: newPassword,
      );

      if (emailResult['success'] == true) {
        return {'success': true, 'message': 'A new password has been sent to your email'};
      } else {
        return {'success': false, 'message': 'Failed to send email: ${emailResult['error']}'};
      }
    } catch (e) {
      print('Forgot password error: $e');
      return {'success': false, 'message': 'An error occurred during password reset'};
    }
  }

  /// Admin-initiated password reset for another user.
  static Future<Map<String, dynamic>> adminResetUserPassword(String targetUserId) async {
    try {
      final profile = await _repository.getProfile(targetUserId);
      if (profile == null) {
        return {'success': false, 'message': 'User not found'};
      }

      final userName = '${profile.prenom} ${profile.nom}'.trim();
      final userEmail = profile.email;

      if (userEmail == null || userEmail.isEmpty) {
        return {'success': false, 'message': 'User has no associated email'};
      }

      final newPassword = _generateRandomPassword();
      final hashedUrl = BCrypt.hashpw(newPassword, BCrypt.gensalt());

      await _repository.updatePassword(targetUserId, hashedUrl);

      final emailResult = await EmailService.sendPasswordResetEmail(
        userEmail: userEmail,
        userName: userName.isEmpty ? profile.username : userName,
        newPassword: newPassword,
      );

      return {
        'success': true, 
        'message': 'Password has been reset and email sent to $userEmail',
        'data': {'newPassword': newPassword} // Return to admin just in case
      };
    } catch (e) {
      print('Admin reset password error: $e');
      return {'success': false, 'message': 'Failed to reset user password'};
    }
  }

  static String _generateRandomPassword([int length = 12]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
    final rnd = Random.secure();
    return List.generate(length, (index) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ── User Settings ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUserSettings(String userId) async {
    try {
      final settings = await _repository.getUserSettings(userId);
      if (settings == null) {
        return {'success': false, 'message': 'Settings not found'};
      }
      return {'success': true, 'data': settings};
    } catch (e) {
      print('Get settings error: $e');
      return {'success': false, 'message': 'Failed to get settings'};
    }
  }

  static Future<Map<String, dynamic>> updateUserSettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _repository.updateUserSettings(userId, settings);
      return {'success': true, 'message': 'Settings updated successfully'};
    } catch (e) {
      print('Update settings error: $e');
      return {'success': false, 'message': 'Failed to update settings'};
    }
  }

  // ── Token helpers ─────────────────────────────────────────────────────────
  static String _generateAccessToken(String userId, String role) {
    final jwt = JWT({
      'userId': userId,
      'role': role,
      'exp': DateTime.now().add(_tokenExpiry).millisecondsSinceEpoch ~/ 1000,
    });
    return jwt.sign(SecretKey(_secret));
  }

  static String _generateRefreshToken(String userId) {
    final jwt = JWT({
      'userId': userId,
      'type': 'refresh',
      'exp': DateTime.now()
              .add(_refreshTokenExpiry)
              .millisecondsSinceEpoch ~/
          1000,
    });
    return jwt.sign(SecretKey(_secret));
  }

  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Future<List<String>> getUserPermissions(String userId) async {
    try {
      final perms = await _repository.getUserPermissions(userId);
      return List<String>.from(perms);
    } catch (e) {
      print('Error getting user permissions: $e');
      return [];
    }
  }
}

// ── WS Ticket helper ─────────────────────────────────────────────────────────
class _WsTicket {
  final String userId;
  final String role;
  final DateTime _expiresAt;

  _WsTicket({required this.userId, required this.role})
      : _expiresAt = DateTime.now().add(const Duration(seconds: 90));

  bool get isExpired => DateTime.now().isAfter(_expiresAt);
}