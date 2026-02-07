import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../notification_service.dart';

class NotificationRoutes {
  late final Router router;

  NotificationRoutes() {
    router = Router()
      ..get('/<userId>', _getUserNotifications)
      ..get('/<userId>/unread-count', _getUnreadNotificationCount)
      ..get('/<notificationId>', _getNotificationById)
      ..put('/<notificationId>/read', _markNotificationAsRead)
      ..put('/<userId>/read-all', _markAllNotificationsAsRead);
  }

  Future<Response> _getUserNotifications(Request request, String userId) async {
    try {
      // Parse query parameters for filtering
      final filter = request.url.queryParameters['filter'];
      
      final result = await NotificationService.getUserNotifications(userId, filter: filter);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _markNotificationAsRead(Request request, String notificationId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final userId = data['userId'] as String?;

      if (userId == null) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'User ID is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await NotificationService.markNotificationAsRead(notificationId, userId);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _markAllNotificationsAsRead(Request request, String userId) async {
    try {
      final result = await NotificationService.markAllNotificationsAsRead(userId);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  Future<Response> _getUnreadNotificationCount(Request request, String userId) async {
    try {
      final result = await NotificationService.getUnreadNotificationCount(userId);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  Future<Response> _getNotificationById(Request request, String notificationId) async {
    try {
      // Extract user_id from query parameters
      final userId = request.url.queryParameters['userId'];
      
      if (userId == null) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'User ID is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      final result = await NotificationService.getNotificationById(notificationId, userId);

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          404,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}