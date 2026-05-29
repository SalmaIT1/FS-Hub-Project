import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/repositories/auth_repository_port.dart';
import '../../data/models/user_model.dart';
import '../../data/models/auth_session_model.dart';
import 'dart:io';
import 'dart:math';
import '../../../email/domain/services/email_service.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  static AuthRepository? _repository;
  static AuthRepositoryPort? _loginPortOverride;
  static String _secret = '';

  static AuthRepository get _repo => _repository ??= AuthRepository();
  static AuthRepositoryPort get _loginPort => _loginPortOverride ?? _repo;

  @visibleForTesting
  static void bindForTest({AuthRepositoryPort? auth}) {
    _loginPortOverride = auth;
  }

  @visibleForTesting
  static void resetBindings() {
    _loginPortOverride = null;
  }

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

  /// Test-only: inject JWT secret without reading .env (unit tests).
  static void initSecretForTests(String secret) {
    _secret = secret;
  }

  static const Duration _tokenExpiry = Duration(hours: 12);
  static const Duration _refreshTokenExpiry = Duration(days: 7);

  // ── Access-token revocation (in-memory blocklist) ────────────────────────
  // Stores tokens that have been explicitly logged out before their expiry.
  // Cleared on server restart — acceptable for dev/MVP. For production,
  // replace with a Redis-backed store.
  // No longer needed: replace with persistent DB store
  // static final Set<String> _revokedTokens = {};

  static void revokeAccessToken(String token) async {
    try {
      await _repo.addToTokenBlocklist(token);
    } catch (e) {
      print('Failed to persist token revocation: $e');
    }
  }

  static Future<bool> isTokenRevoked(String token) async {
    try {
      return await _repo.isTokenInBlocklist(token);
    } catch (e) {
      // P2-1 SECURITY FIX: Fail-closed posture.
      // If the DB is unavailable we cannot verify the token blocklist,
      // so we DENY access rather than allow a potentially revoked session.
      // The client will receive a 401 and must re-authenticate.
      print('[AUTH] isTokenRevoked DB error \u2014 failing closed: $e');
      return true;
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

  // ── Media tickets (short-lived, scoped to one file — no JWT in URLs) ─────
  static final Map<String, _MediaTicket> _mediaTickets = {};

  static String issueMediaTicket({
    required String userId,
    required String role,
    required String storedFilename,
  }) {
    _mediaTickets.removeWhere((_, t) => t.isExpired);
    final ticket = const Uuid().v4();
    _mediaTickets[ticket] = _MediaTicket(
      userId: userId,
      role: role,
      storedFilename: storedFilename,
    );
    return ticket;
  }

  /// Validates one-time media ticket for GET /media/{filename}.
  static Map<String, String>? consumeMediaTicket(
    String ticket,
    String requestedFilename,
  ) {
    final t = _mediaTickets.remove(ticket);
    if (t == null || t.isExpired) return null;
    if (t.storedFilename != requestedFilename) return null;
    return {'userId': t.userId, 'role': t.role};
  }

  // ── Payslip tickets (browser print — no JWT in URL) ─────────────────────
  static final Map<String, _PayslipTicket> _payslipTickets = {};

  static String issuePayslipTicket({
    required String userId,
    required String role,
    required int salaryId,
  }) {
    _payslipTickets.removeWhere((_, t) => t.isExpired);
    final ticket = const Uuid().v4();
    _payslipTickets[ticket] = _PayslipTicket(
      userId: userId,
      role: role,
      salaryId: salaryId,
    );
    return ticket;
  }

  static Map<String, String>? consumePayslipTicket(
    String ticket,
    int requestedSalaryId,
  ) {
    final t = _payslipTickets.remove(ticket);
    if (t == null || t.isExpired) return null;
    if (t.salaryId != requestedSalaryId) return null;
    return {'userId': t.userId, 'role': t.role};
  }

  // ── Login ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final userRow = await _loginPort.findUserByUsernameOrEmail(username);

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
        isValid = false;
      }

      if (!isValid) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      await _loginPort.updateLastLogin(userId);

      final accessToken = _generateAccessToken(userId, userRole ?? 'Employé');
      final refreshToken = _generateRefreshToken(userId);
      try {
        await _loginPort.saveRefreshToken(
          userId: userId,
          token: refreshToken,
          expiresAt: DateTime.now().add(_refreshTokenExpiry),
        );
      } catch (e) {
        print('[AUTH] Failed to persist refresh token: $e');
      }

      final session = AuthSessionModel(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: UserModel.fromMap(userRow),
      );

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
        await _repo.revokeAllUserRefreshTokens(userId);
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
      final type = jwt.payload['type']?.toString();

      if (userId == null || type != 'refresh') {
        return {'success': false, 'message': 'Invalid refresh token payload'};
      }

      final info = await _repo.getRefreshTokenInfo(refreshToken, userId);

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

      final userRole = await _repo.getUserRole(userId);
      if (userRole == null) {
        return {'success': false, 'message': 'User not found'};
      }

      final newAccessToken = _generateAccessToken(userId, userRole);
      final newRefreshToken = _generateRefreshToken(userId);

      await _repo.revokeRefreshToken(refreshToken);
      await _repo.saveRefreshToken(
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
      return {'success': false, 'message': 'Internal Server Error'};
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

      final profile = await _repo.getProfile(userId);

      if (profile == null) {
        return {'success': false, 'message': 'User not found'};
      }

      return {
        'success': true,
        'data': profile.toJson()
      };
    } catch (e) {
      print('Get profile error: $e');
      return {'success': false, 'message': 'Internal Server Error'};
    }
  }

  // ── Change Password ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> changePassword(String userId, String oldPassword, String newPassword) async {
    try {
      final storedHash = await _repo.getPasswordHash(userId);
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
      await _repo.updatePassword(userId, newHash);
      return {'success': true, 'message': 'Password updated successfully'};
    } catch (e) {
      print('Change password error: $e');
      return {'success': false, 'message': 'Internal Server Error'};
    }
  }

  // ── Forgot Password & Admin Reset ─────────────────────────────────────────

  /// HARSH FIX: Password Complexity check.
  static bool validatePasswordComplexity(String password) {
    if (password.length < 8) return false;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpec  = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUpper && hasLower && hasDigit && hasSpec;
  }

  /// Self-service forgot password. 
  /// Issuing a token instead of changing password instantly (prevents lockout).
  /// Self-service forgot password. 
  /// Issuing a token and sending an email for secure recovery.
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    const uniformResponse = {
      'success': true, 
      'message': 'If an account exists for this email, you will receive a reset link shortly.'
    };
    try {
      final userRow = await _repo.findUserByUsernameOrEmail(email);
      if (userRow == null) return uniformResponse;

      final userId = userRow['id'].toString();
      final userEmail = userRow['email'] as String? ?? email;
      final userName = userRow['prenom']?.toString() ?? 'User';

      // 1. Generate Token
      final token = const Uuid().v4();
      final hash = sha256.convert(utf8.encode(token)).toString();
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      // 2. Save Token Hash
      await _repo.savePasswordResetToken(
        userId: userId, 
        tokenHash: hash, 
        expiresAt: expiresAt
      );

      // 3. Dispatch Email
      await EmailService.sendPasswordResetEmail(
        userEmail: userEmail,
        userName: userName,
        resetToken: token,
      );

      return uniformResponse;
    } catch (e) {
      print('[AUTH] Forgot password error: $e');
      return uniformResponse;
    }
  }

  /// Consumes a reset token and sets a new password.
  static Future<Map<String, dynamic>> resetPasswordWithToken(String token, String newPassword) async {
    try {
      if (!validatePasswordComplexity(newPassword)) {
        return {'success': false, 'message': 'Password is too weak. Must have upper, lower, digit and special.'};
      }

      final hash = sha256.convert(utf8.encode(token)).toString();
      final info = await _repo.getResetTokenInfo(hash);

      if (info == null || info['is_used'] == true) {
        return {'success': false, 'message': 'Invalid or already used token.'};
      }

      final expiresAt = DateTime.parse(info['expires_at'].toString());
      if (DateTime.now().isAfter(expiresAt)) {
        return {'success': false, 'message': 'Token expired.'};
      }

      final userId = info['user_id'].toString();
      final hashedPassword = BCrypt.hashpw(newPassword, BCrypt.gensalt());
      
      await _repo.updatePassword(userId, hashedPassword);
      await _repo.markResetTokenUsed(hash);

      return {'success': true, 'message': 'Password has been reset.'};
    } catch (e) {
      print('resetPasswordWithToken error: $e');
      return {'success': false, 'message': 'Internal Server Error'};
    }
  }

  /// Admin-initiated password reset for another user.
  static Future<Map<String, dynamic>> adminResetUserPassword(String targetUserId) async {
    try {
      final profile = await _repo.getProfile(targetUserId);
      if (profile == null) return {'success': false, 'message': 'User not found'};

      final userEmail = profile.email;
      if (userEmail == null || userEmail.isEmpty) return {'success': false, 'message': 'User has no email'};

      final token = const Uuid().v4();
      final hash = sha256.convert(utf8.encode(token)).toString();
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      await _repo.savePasswordResetToken(
        userId: targetUserId, 
        tokenHash: hash, 
        expiresAt: expiresAt
      );

      await EmailService.sendPasswordResetEmail(
        userEmail: userEmail,
        userName: profile.prenom ?? 'User',
        resetToken: token,
      );

      return {
        'success': true, 
        'message': 'A reset link has been sent to $userEmail',
      };
    } catch (e) {
      print('Admin reset password error: $e');
      return {'success': false, 'message': 'Internal Server Error'};
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
      final settings = await _repo.getUserSettings(userId);
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
      await _repo.updateUserSettings(userId, settings);
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
      final perms = await _repo.getUserPermissions(userId);
      return List<String>.from(perms);
    } catch (e) {
      print('Error getting user permissions: $e');
      // HARSH FIX: Don't leak internals even in private logs if possible.
      return [];
    }
  }
  static Future<String> registerClientAccount(String email, String phone) async {
    // Client account setup: Username = Email, Password = Phone Number
    final userId = await _repo.createUser(
      username: email,
      password: phone,
      role: 'Client',
    );

    try {
      await EmailService.sendNewPasswordEmail(
        userEmail: email,
        userName: 'Client',
        newPassword: phone,
      );
    } catch (e) {
      print('[AUTH] Warning: Failed to send welcome email to $email: $e');
    }
    
    return userId;
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

class _MediaTicket {
  final String userId;
  final String role;
  final String storedFilename;
  final DateTime _expiresAt;

  _MediaTicket({
    required this.userId,
    required this.role,
    required this.storedFilename,
  }) : _expiresAt = DateTime.now().add(const Duration(minutes: 5));

  bool get isExpired => DateTime.now().isAfter(_expiresAt);
}

class _PayslipTicket {
  final String userId;
  final String role;
  final int salaryId;
  final DateTime _expiresAt;

  _PayslipTicket({
    required this.userId,
    required this.role,
    required this.salaryId,
  }) : _expiresAt = DateTime.now().add(const Duration(minutes: 5));

  bool get isExpired => DateTime.now().isAfter(_expiresAt);
}