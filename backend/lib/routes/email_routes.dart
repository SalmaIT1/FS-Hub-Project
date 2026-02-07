import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../email_service.dart';

class EmailRoutes {
  late final Router router;

  EmailRoutes() {
    router = Router()
      ..post('/send-password-reset', _sendPasswordResetEmail)
      ..post('/send-admin-notification', _sendAdminNotification);
  }

  Future<Response> _sendPasswordResetEmail(Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      final userEmail = payload['userEmail'];
      final userName = payload['userName'];
      final newPassword = payload['newPassword'];

      final result = await EmailService.sendPasswordResetEmail(
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
        return Response(
          500,
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
  }

  Future<Response> _sendAdminNotification(Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      final adminEmail = payload['adminEmail'];
      final userEmail = payload['userEmail'];
      final userName = payload['userName'];
      final requestId = payload['requestId'];

      final result = await EmailService.sendPasswordResetRequestNotification(
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
        return Response(
          500,
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
  }
}