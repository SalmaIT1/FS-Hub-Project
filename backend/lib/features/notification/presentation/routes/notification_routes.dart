import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/notification_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class NotificationRoutes {
  late final Router router;

  NotificationRoutes() {
    final secured = Pipeline().addMiddleware(requireAuth());
    router = Router()
      ..get('/', secured.addHandler(_getUserNotifications))
      ..get('/unread-count', secured.addHandler(_getUnreadNotificationCount))
      ..get('/<id>', (Request r, String id) => secured.addHandler((req) => _handleIdGet(req, id))(r))
      ..get('/<id>/unread-count', (Request r, String id) => secured.addHandler((req) => _getUnreadNotificationCount(req))(r))
      ..put('/<id>/read', (Request r, String id) => secured.addHandler((req) => _markNotificationAsRead(req, id))(r))
      ..put('/read-all', secured.addHandler(_markAllNotificationsAsRead));
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
