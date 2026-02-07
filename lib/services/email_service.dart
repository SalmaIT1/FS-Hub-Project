import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  static const String _baseUrl = 'http://localhost:8080';
  static const String adminEmail = 'admin@fshub.com';

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

  /// Send password reset email to user via backend API
  static Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String userEmail,
    required String userName,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/email/send-password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userEmail': userEmail,
          'userName': userName,
          'newPassword': newPassword,
        }),
      );

      final result = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        print('=== EMAIL SENT SUCCESSFULLY ===');
        print('To: $userEmail');
        print('Subject: Your FS Hub Password Has Been Reset');
        print('=============================');
        return result;
      } else {
        print('Email sending failed: ${result['error']}');
        return result;
      }
    } catch (e) {
      print('Email sending error: $e');
      return {
        'success': false,
        'error': 'Failed to send email: ${e.toString()}',
      };
    }
  }

  /// Send notification email to admin about password reset request via backend API
  static Future<Map<String, dynamic>> sendPasswordResetRequestNotification({
    required String adminEmail,
    required String userEmail,
    required String userName,
    required String requestId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/email/send-admin-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'adminEmail': adminEmail,
          'userEmail': userEmail,
          'userName': userName,
          'requestId': requestId,
        }),
      );

      final result = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        print('=== ADMIN NOTIFICATION SENT ===');
        print('To: $adminEmail');
        print('Subject: New Password Reset Request - FS Hub');
        print('===============================');
        return result;
      } else {
        print('Admin notification failed: ${result['error']}');
        return result;
      }
    } catch (e) {
      print('Admin notification error: $e');
      return {
        'success': false,
        'error': 'Failed to send admin notification: ${e.toString()}',
      };
    }
  }

  /// Test email configuration via backend
  static Future<Map<String, dynamic>> testEmailConfiguration() async {
    try {
      final result = await sendPasswordResetEmail(
        userEmail: 'test@example.com',
        userName: 'Test User',
        newPassword: 'TestPassword123!',
      );

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'Email configuration test failed: ${e.toString()}',
      };
    }
  }
}
