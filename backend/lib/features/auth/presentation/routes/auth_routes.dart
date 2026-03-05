import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/auth_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

class AuthRoutes {
  late final Router router;

  AuthRoutes() {
    // Public routes (no auth middleware):
    final publicRouter = Router()
      ..post('/login', _login)
      ..post('/refresh', _refreshToken);

    // Protected routes:
    final protectedRouter = Router()
      ..post('/logout', _logout)
      ..get('/profile', _getProfile)
      ..post('/change-password', _changePassword)
      ..get('/settings', _getUserSettings)
      ..post('/settings', _updateUserSettings)
      ..post('/ws-ticket', _getWsTicket);

    final protectedHandler = Pipeline()
        .addMiddleware(requireAuth())
        .addHandler(protectedRouter.call);

    router = Router()
      ..mount('/', publicRouter.call)
      ..mount('/', protectedHandler);
  }

  Future<Response> _login(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Accept either 'email' or 'username' field
      final credential = data['email'] ?? data['username'];
      final password = data['password'];

      if (credential == null || credential.toString().trim().isEmpty ||
          password == null || password.toString().isEmpty) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'email or username and password are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await AuthService.login(
        credential.toString(),
        password.toString(),
      );

      if (result['success'] == true) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          401,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('Login route error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Login failed'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _logout(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      final token = authHeader?.startsWith('Bearer ') == true
          ? authHeader!.split(' ')[1]
          : null;

      await AuthService.logout(token);

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Logged out successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _refreshToken(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final refreshToken = data['refreshToken'];
      if (refreshToken == null || refreshToken.toString().isEmpty) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'refreshToken is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await AuthService.refreshToken(refreshToken.toString());

      if (result['success'] == true) {
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

  Future<Response> _getProfile(Request request) async {
    try {
      final token = request.headers['authorization']?.split(' ')[1];
      final result = await AuthService.getProfile(token);

      if (result['success'] == true) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          403,
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

  /// Changes the user's password
  Future<Response> _changePassword(Request request) async {
    try {
      final userId = request.authUserId; // Set by auth_middleware
      if (userId == null) {
        return Response(
          401,
          body: jsonEncode({'success': false, 'message': 'Unauthorized'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final oldPassword = data['oldPassword'];
      final newPassword = data['newPassword'];

      if (oldPassword == null || newPassword == null) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'oldPassword and newPassword are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await AuthService.changePassword(userId, oldPassword, newPassword);

      if (result['success'] == true) {
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


  Future<Response> _getUserSettings(Request request) async {
    try {
      final userId = request.authUserId;
      if (userId == null) return Response(401, body: jsonEncode({'success': false, 'message': 'Unauthorized'}), headers: {'Content-Type': 'application/json'});

      final result = await AuthService.getUserSettings(userId);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> _updateUserSettings(Request request) async {
    try {
      final userId = request.authUserId;
      if (userId == null) return Response(401, body: jsonEncode({'success': false, 'message': 'Unauthorized'}), headers: {'Content-Type': 'application/json'});

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final result = await AuthService.updateUserSettings(userId, data);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  /// Issues a short-lived (90 second) one-time WS ticket.
  /// The Flutter client calls this immediately before opening the WebSocket.
  Future<Response> _getWsTicket(Request request) async {
    final userId = request.authUserId;
    final userRole = request.authUserRole;
    final ticket = AuthService.issueWsTicket(userId, userRole);
    return Response.ok(
      jsonEncode({'success': true, 'ticket': ticket}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}