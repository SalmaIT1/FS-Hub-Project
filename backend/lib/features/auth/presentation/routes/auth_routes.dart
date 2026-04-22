import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/auth_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';
import '../../../../core/middleware/rate_limit_middleware.dart';

class AuthRoutes {
  late final Router router;

  AuthRoutes() {
    router = Router();

    // -- Public Routes --
    router.post('/login', Pipeline()
        .addMiddleware(rateLimit(maxAttempts: 5, windowSeconds: 900))
        .addHandler((r) => _login(r)));
    router.post('/refresh', _refreshToken);
    router.post('/forgot-password', Pipeline()
        .addMiddleware(rateLimit(maxAttempts: 3, windowSeconds: 3600))
        .addHandler((r) => _forgotPassword(r)));
    router.post('/reset-password', Pipeline()
        .addMiddleware(rateLimit(maxAttempts: 3, windowSeconds: 3600))
        .addHandler((r) => _resetPassword(r)));

    // -- Protected Routes --
    // We apply requireAuth() only to these specific handlers.
    Handler secured(Function handler) => 
        Pipeline().addMiddleware(requireAuth()).addHandler((r) => handler(r) as FutureOr<Response>);

    router.post('/logout', secured(_logout));
    router.get('/profile', secured(_getProfile));
    router.post('/change-password', Pipeline()
        .addMiddleware(requireAuth())
        .addMiddleware(rateLimit(maxAttempts: 5, windowSeconds: 3600))
        .addHandler((r) => _changePassword(r)));
    router.get('/settings', secured(_getUserSettings));
    router.post('/settings', _updateUserSettings); // _updateUserSettings is already a handler
    router.post('/ws-ticket', secured(_getWsTicket));
    
    // Admin-guarded route
    router.post('/admin/reset-user-password', (Request req) => 
      Pipeline()
        .addMiddleware(requireAuth())
        .addMiddleware(requirePermission('manage_users'))
        .addHandler((r) => _adminResetUserPassword(r))(req));
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
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final result = await AuthService.login(
        credential.toString(),
        password.toString(),
      );

      if (result['success'] == true) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      } else {
        return Response(
          401,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
    } catch (e) {
      print('Login route error: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Login failed'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
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
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Internal server error'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
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
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final result = await AuthService.refreshToken(refreshToken.toString());

      if (result['success'] == true) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Internal Server Error'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
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
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      } else {
        return Response(
          403,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _resetPassword(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final token = data['token']?.toString();
      final newPassword = data['new_password']?.toString();

      if (token == null || newPassword == null) {
        return Response.badRequest(body: jsonEncode({'success': false, 'message': 'Token and new_password are required'}));
      }

      final res = await AuthService.resetPasswordWithToken(token, newPassword);
      if (!res['success']) return Response.badRequest(body: jsonEncode(res));

      return Response.ok(jsonEncode(res));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Internal Server Error'}));
    }
  }

  /// Changes the user's password
  Future<Response> _changePassword(Request request) async {
    try {
      final userId = request.authUserId;

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final oldPassword = data['oldPassword']?.toString() ?? data['currentPassword']?.toString();
      final newPassword = data['newPassword']?.toString();

      if (oldPassword == null || newPassword == null) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'oldPassword and newPassword are required'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      // HARSH FIX: Complexity requirement
      if (!AuthService.validatePasswordComplexity(newPassword)) {
        return Response(
          400,
          body: jsonEncode({
            'success': false, 
            'message': 'Password too weak. Must be >= 8 chars with Upper, Lower, Digit, Spec.'
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final result = await AuthService.changePassword(userId, oldPassword, newPassword);

      if (result['success'] == true) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      } else {
        return Response(
          400,
          body: jsonEncode(result),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Internal Server Error'}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }


  Future<Response> _getUserSettings(Request request) async {
    try {
      final userId = request.authUserId;

      final result = await AuthService.getUserSettings(userId);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    }
  }

  Future<Response> _updateUserSettings(Request request) async {
    try {
      final userId = request.authUserId;

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final result = await AuthService.updateUserSettings(userId, data);
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}), headers: {'Content-Type': 'application/json; charset=utf-8'});
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
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }
  Future<Response> _forgotPassword(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final email = data['email'];

      if (email == null || email.toString().isEmpty) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'Email is required'}), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }

      final result = await AuthService.forgotPassword(email.toString());
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    }
  }

  Future<Response> _adminResetUserPassword(Request request) async {
    try {

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final targetUserId = data['userId'];

      if (targetUserId == null || targetUserId.toString().isEmpty) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'userId is required'}), headers: {'Content-Type': 'application/json; charset=utf-8'});
      }

      final result = await AuthService.adminResetUserPassword(targetUserId.toString());
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json; charset=utf-8'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': e.toString()}), headers: {'Content-Type': 'application/json; charset=utf-8'});
    }
  }
}