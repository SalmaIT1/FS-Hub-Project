import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fs_hub/core/config/app_config.dart';
import 'package:fs_hub/core/security/token_storage.dart';

/// Short-lived ticket for opening payslip HTML in the browser (no JWT in URL).
class PayslipAuthService {
  static Future<String?> ticketForSalary(int salaryId) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiV1BaseUrl}/auth/payslip-ticket'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'salary_id': salaryId}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final ticket = body['ticket']?.toString();
        if (ticket != null && ticket.isNotEmpty) return ticket;
      }
    } catch (_) {}
    return null;
  }
}
