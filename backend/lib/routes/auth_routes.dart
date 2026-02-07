import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/auth_service.dart';

class AuthRoutes {
  late final Router router;

  AuthRoutes() {
    router = Router()
      ..post('/login', _login)
      ..post('/logout', _logout)
      ..post('/refresh', _refreshToken)
      ..get('/profile', _getProfile);
  }

  Future<Response> _login(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final result = await AuthService.login(
        data['username'] as String,
        data['password'] as String,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.unauthorized(
          jsonEncode(result),
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

  Future<Response> _logout(Request request) async {
    try {
      // Extract token from headers
      final token = request.headers['authorization']?.split(' ')[1];
      
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
      final data = jsonDecode(body);

      final result = await AuthService.refreshToken(
        data['refreshToken'] as String,
      );

      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.badRequest(
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
      // Extract token from headers
      final token = request.headers['authorization']?.split(' ')[1];
      
      final result = await AuthService.getProfile(token);
      
      if (result['success']) {
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.forbidden(
          jsonEncode(result),
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