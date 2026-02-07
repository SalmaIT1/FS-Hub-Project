import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
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

  /// Generate a random password
  static String generateRandomPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    var password = '';
    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }
    return password;
  }

  /// Send password reset email to user
  static Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String userEmail,
    required String userName,
    required String newPassword,
  }) async {
    try {
      if (!_emailEnabled) {
        print('Email service is disabled. Enable it by setting EMAIL_ENABLED=true in .env');
        return {
          'success': false,
          'error': 'Email service is disabled',
        };
      }

      final subject = 'Your FS Hub Password Has Been Reset';
      final body = _buildPasswordResetEmail(userName, newPassword);

      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: true,
      );

      // Create and send email message
      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(userEmail)
        ..subject = subject
        ..html = body;

      await send(message, smtpServer);

      print('=== EMAIL SENT SUCCESSFULLY ===');
      print('To: $userEmail');
      print('Subject: $subject');
      print('=============================');

      return {
        'success': true,
        'message': 'Password reset email sent successfully to $userEmail',
      };
    } catch (e) {
      print('Email sending error: $e');
      return {
        'success': false,
        'error': 'Failed to send email: ${e.toString()}',
      };
    }
  }

  /// Send notification email to admin about password reset request
  static Future<Map<String, dynamic>> sendPasswordResetRequestNotification({
    required String adminEmail,
    required String userEmail,
    required String userName,
    required String requestId,
  }) async {
    try {
      if (!_emailEnabled) {
        print('Admin notification email disabled');
        return {
          'success': false,
          'error': 'Email service is disabled',
        };
      }

      final subject = 'New Password Reset Request - FS Hub';
      final body = _buildPasswordResetRequestEmail(userName, userEmail, requestId);

      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _smtpUsername,
        password: _smtpPassword,
        ssl: false,
        allowInsecure: true,
      );

      // Create and send email message
      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(adminEmail)
        ..subject = subject
        ..html = body;

      await send(message, smtpServer);

      print('=== ADMIN NOTIFICATION SENT ===');
      print('To: $adminEmail');
      print('Subject: $subject');
      print('===============================');

      return {
        'success': true,
        'message': 'Admin notification sent successfully',
      };
    } catch (e) {
      print('Admin notification error: $e');
      return {
        'success': false,
        'error': 'Failed to send admin notification: ${e.toString()}',
      };
    }
  }

  /// Build HTML email template for password reset
  static String _buildPasswordResetEmail(String userName, String newPassword) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password Reset - FS Hub</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            background-color: #ffffff;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 24px;
            font-weight: bold;
            color: #D4AF37;
            margin-bottom: 10px;
        }
        .title {
            color: #333;
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 20px;
        }
        .password-box {
            background-color: #f8f9fa;
            border: 2px dashed #D4AF37;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
            border-radius: 8px;
        }
        .password {
            font-size: 20px;
            font-weight: bold;
            color: #D4AF37;
            letter-spacing: 2px;
            font-family: 'Courier New', monospace;
        }
        .warning {
            background-color: #fff3cd;
            border: 1px solid #ffeaa7;
            color: #856404;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #666;
            font-size: 14px;
        }
        .button {
            display: inline-block;
            background-color: #D4AF37;
            color: #000;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 5px;
            font-weight: 600;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">FS HUB</div>
            <h1 class="title">Password Reset Complete</h1>
        </div>
        
        <p>Dear <strong>$userName</strong>,</p>
        
        <p>Your password reset request has been approved by an administrator. Your account password has been successfully reset.</p>
        
        <div class="password-box">
            <p style="margin: 0; font-size: 14px; color: #666;">Your New Password:</p>
            <div class="password">$newPassword</div>
        </div>
        
        <div class="warning">
            <strong>⚠️ Important Security Notice:</strong><br>
            Please change this password immediately after logging in for the first time. This temporary password should only be used to access your account and set up your own secure password.
        </div>
        
        <p>You can now log in to your FS Hub account using this new password.</p>
        
        <div style="text-align: center;">
            <a href="#" class="button">Go to FS Hub</a>
        </div>
        
        <p>If you did not request this password reset, please contact our support team immediately.</p>
        
        <div class="footer">
            <p>This is an automated message from FS Hub. Please do not reply to this email.</p>
            <p>© 2024 FS Hub. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }

  /// Build HTML email template for admin notification
  static String _buildPasswordResetRequestEmail(String userName, String userEmail, String requestId) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password Reset Request - FS Hub Admin</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            background-color: #ffffff;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 24px;
            font-weight: bold;
            color: #D4AF37;
            margin-bottom: 10px;
        }
        .title {
            color: #333;
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 20px;
        }
        .info-box {
            background-color: #e3f2fd;
            border: 1px solid #2196f3;
            color: #1565c0;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #666;
            font-size: 14px;
        }
        .button {
            display: inline-block;
            background-color: #D4AF37;
            color: #000;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 5px;
            font-weight: 600;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">FS HUB</div>
            <h1 class="title">Password Reset Request</h1>
        </div>
        
        <p>A user has requested a password reset for their FS Hub account.</p>
        
        <div class="info-box">
            <strong>Request Details:</strong><br>
            User Name: <strong>$userName</strong><br>
            User Email: <strong>$userEmail</strong><br>
            Request ID: <strong>$requestId</strong><br>
            Request Time: <strong>${DateTime.now().toString()}</strong>
        </div>
        
        <p>Please review this request in the admin panel and approve or reject it accordingly.</p>
        
        <div style="text-align: center;">
            <a href="#" class="button">Review Request</a>
        </div>
        
        <p>This request requires your attention to ensure the security of user accounts.</p>
        
        <div class="footer">
            <p>This is an automated message from FS Hub Admin System.</p>
            <p>© 2024 FS Hub. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }

  /// Create email API routes
  static Router createEmailRoutes() {
    final router = Router();

    // Send password reset email
    router.post('/send-password-reset', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final userEmail = payload['userEmail'];
        final userName = payload['userName'];
        final newPassword = payload['newPassword'];

        final result = await sendPasswordResetEmail(
          userEmail: userEmail,
          userName: userName,
          newPassword: newPassword,
        );

        if (result['success']) {
          return Response.ok(
            jsonEncode(result),
            headers: {'Content-Type': 'application/json'},
          );
        } else {
          return Response.internalServerError(
            body: jsonEncode(result),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // Send admin notification
    router.post('/send-admin-notification', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final adminEmail = payload['adminEmail'];
        final userEmail = payload['userEmail'];
        final userName = payload['userName'];
        final requestId = payload['requestId'];

        final result = await sendPasswordResetRequestNotification(
          adminEmail: adminEmail,
          userEmail: userEmail,
          userName: userName,
          requestId: requestId,
        );

        if (result['success']) {
          return Response.ok(
            jsonEncode(result),
            headers: {'Content-Type': 'application/json'},
          );
        } else {
          return Response.internalServerError(
            body: jsonEncode(result),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    return router;
  }
}
