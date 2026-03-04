import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:dotenv/dotenv.dart';

class EmailService {
  static late DotEnv _env;
  
  static void initialize() {
    _env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
  }
  
  static String get _smtpHost => _env['SMTP_HOST'] ?? 'smtp.gmail.com';
  static int get _smtpPort => int.tryParse(_env['SMTP_PORT'] ?? '587') ?? 587;
  static String get _smtpUsername => _env['SMTP_USERNAME'] ?? 'your-email@gmail.com';
  static String get _smtpPassword => _env['SMTP_PASSWORD'] ?? 'your-app-password';
  static String get _fromEmail => _env['SMTP_FROM_EMAIL'] ?? 'your-email@gmail.com';
  static String get _fromName => _env['SMTP_FROM_NAME'] ?? 'FS Hub Support';
  static bool get _emailEnabled => _env['EMAIL_ENABLED'] == 'true';

  static Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String userEmail,
    required String userName,
    required String newPassword,
  }) async {
    try {
      if (!_emailEnabled) return {'success': false, 'error': 'Email service is disabled'};

      final subject = 'Your FS Hub Password Has Been Reset';
      final body = _buildPasswordResetEmail(userName, newPassword);

      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: true,
      );

      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(userEmail)
        ..subject = subject
        ..html = body;

      await send(message, smtpServer);
      return {'success': true, 'message': 'Password reset email sent to $userEmail'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendPasswordResetRequestNotification({
    required String adminEmail,
    required String userEmail,
    required String userName,
    required String requestId,
  }) async {
    try {
      if (!_emailEnabled) return {'success': false, 'error': 'Email service is disabled'};

      final subject = 'New Password Reset Request - FS Hub';
      final body = _buildPasswordResetRequestEmail(userName, userEmail, requestId);

      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: true,
      );

      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(adminEmail)
        ..subject = subject
        ..html = body;

      await send(message, smtpServer);
      return {'success': true, 'message': 'Admin notification sent'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static String _buildPasswordResetEmail(String userName, String newPassword) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Password Reset - FS Hub</title>
</head>
<body>
    <h1>Password Reset Complete</h1>
    <p>Dear $userName,</p>
    <p>Your password has been reset to: <strong>$newPassword</strong></p>
    <p>Please change it immediately after logging in.</p>
</body>
</html>
    ''';
  }

  static String _buildPasswordResetRequestEmail(String userName, String userEmail, String requestId) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reset Request - FS Hub</title>
</head>
<body>
    <h1>New Password Reset Request</h1>
    <p>User: $userName ($userEmail)</p>
    <p>Request ID: $requestId</p>
</body>
</html>
    ''';
  }
}
