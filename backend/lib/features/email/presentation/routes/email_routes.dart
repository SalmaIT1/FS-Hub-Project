import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/email_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class EmailRoutes {
  late final Router router;

  EmailRoutes() {
    router = Router()
      ..post('/send-password-reset', _sendPasswordResetEmail)
      ..post('/send-admin-notification', _sendAdminNotification);
  }

  Future<Response> _sendPasswordResetEmail(Request request) async {
    try {
      if (!request.isAdmin) return Response.forbidden(jsonEncode({'success': false, 'message': 'Admin only'}));
      
      final payload = jsonDecode(await request.readAsString());
      final result = await EmailService.sendPasswordResetEmail(
        userEmail: payload['userEmail'],
        userName: payload['userName'],
        newPassword: payload['newPassword'],
      );

      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'error': e.toString()}));
    }
  }

  Future<Response> _sendAdminNotification(Request request) async {
    try {
      if (!request.isAdmin) return Response.forbidden(jsonEncode({'success': false, 'message': 'Admin only'}));

      final payload = jsonDecode(await request.readAsString());
      final result = await EmailService.sendPasswordResetRequestNotification(
        adminEmail: payload['adminEmail'],
        userEmail: payload['userEmail'],
        userName: payload['userName'],
        requestId: payload['requestId'],
      );

      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'error': e.toString()}));
    }
  }
}
