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

  static SmtpServer _getSmtpServer() {
    return SmtpServer(
      _smtpHost,
      port: _smtpPort,
      username: _smtpUsername,
      password: _smtpPassword,
      ssl: _smtpPort == 465,
      allowInsecure: _smtpPort != 465,
    );
  }

  static Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String userEmail,
    required String userName,
    required String resetToken,
  }) async {
    try {
      if (!_emailEnabled) return {'success': false, 'error': 'Email service is disabled'};

      final subject = 'Your FS Hub Password Reset Link';
      final body = _buildPasswordResetEmail(userName, resetToken);

      final smtpServer = _getSmtpServer();

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

  static Future<Map<String, dynamic>> sendNewPasswordEmail({
    required String userEmail,
    required String userName,
    required String newPassword,
  }) async {
    try {
      if (!_emailEnabled) return {'success': false, 'error': 'Email service is disabled'};

      final subject = 'Your new password for FS Hub';
      final body = _buildNewPasswordEmail(userName, newPassword);

      final smtpServer = _getSmtpServer();

      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(userEmail)
        ..subject = subject
        ..html = body;

      await send(message, smtpServer);
      return {'success': true, 'message': 'New password emailed to $userEmail'};
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

      final smtpServer = _getSmtpServer();

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

  static String _buildPasswordResetEmail(String userName, String resetToken) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Password Reset - FS Hub</title>
</head>
<body>
    <h1>Password Reset Request</h1>
    <p>Dear $userName,</p>
    <p>A password reset has been requested for your account. Please use the following token or link to reset it:</p>
    <p>Token: <strong>$resetToken</strong></p>
    <p>If you did not request this, please ignore this email.</p>
</body>
</html>
    ''';
  }

  static String _buildNewPasswordEmail(String userName, String newPassword) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Your New Password - FS Hub</title>
</head>
<body>
    <h1>Password Change</h1>
    <p>Dear $userName,</p>
    <p>Your password has been successfully reset by an administrator.</p>
    <p>Your new password is: <strong>$newPassword</strong></p>
    <p>Please log in and we recommend you change this password to a personal one.</p>
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
