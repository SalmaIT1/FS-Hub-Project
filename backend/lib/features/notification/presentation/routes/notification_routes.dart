import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/notification_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class NotificationRoutes {
  late final Router router;

  NotificationRoutes() {
    router = Router()
      ..get('/', _getUserNotifications)
      ..get('/unread-count', _getUnreadNotificationCount)
      ..get('/<id>', _handleIdGet) // Disambiguate notification vs user
      ..get('/<id>/unread-count', _getUnreadNotificationCount)
      ..put('/<id>/read', _markNotificationAsRead)
      ..put('/<id>/read-all', _markAllNotificationsAsRead)
      ..put('/read-all', _markAllNotificationsAsRead);
  }

  Future<Response> _handleIdGet(Request request, String id) async {
    // Check if it's the current user's ID
    final authId = request.authUserId;
    if (id == authId) {
      return _getUserNotifications(request);
    }
    
    // Otherwise try as notification ID
    return _getNotificationById(request, id);
  }

  Future<Response> _getUserNotifications(Request request) async {
    try {
      final userId = request.authUserId;
      final filter = request.url.queryParameters['filter'];
      final result = await NotificationService.getUserNotifications(userId, filter: filter);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response(400, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal server error'}));
    }
  }

  Future<Response> _markNotificationAsRead(Request request, String notificationId) async {
    try {
      final userId = request.authUserId;
      final result = await NotificationService.markNotificationAsRead(notificationId, userId);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response(400, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal server error'}));
    }
  }

  Future<Response> _markAllNotificationsAsRead(Request request) async {
    try {
      final userId = request.authUserId;
      final result = await NotificationService.markAllNotificationsAsRead(userId);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response(400, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal server error'}));
    }
  }
  
  Future<Response> _getUnreadNotificationCount(Request request) async {
    try {
      final userId = request.authUserId;
      final result = await NotificationService.getUnreadNotificationCount(userId);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response(400, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal server error'}));
    }
  }
  
  Future<Response> _getNotificationById(Request request, String notificationId) async {
    try {
      final userId = request.authUserId;
      final result = await NotificationService.getNotificationById(notificationId, userId);

      if (result['success']) {
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        return Response(404, body: jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal server error'}));
    }
  }
}
