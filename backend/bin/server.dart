import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:crypto/crypto.dart';
import '../lib/db.dart';
import '../lib/employee_service.dart';

// Secret for JWT (In production, load from .env)
const jwtSecret = 'forever_software_secret_key_2026';

// CORS Middleware with Error Handling
Middleware corsHeaders() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };

  return (Handler handler) {
    return (Request request) async {
      // Handle preflight requests
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }

      try {
        final response = await handler(request);
        return response.change(headers: corsHeaders);
      } catch (e, stack) {
        print('INTERNAL SERVER ERROR: $e');
        print(stack);
        return Response.internalServerError(
          body: jsonEncode({'error': 'Internal Server Error', 'details': e.toString()}),
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        );
      }
    };
  };
}

void main() async {
  final router = Router();

  // Health Check Endpoint
  router.get('/health', (Request request) async {
    return Response.ok(jsonEncode({
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
      'service': 'FS-Hub Backend'
    }));
  });

  // Login Endpoint
  router.post('/login', (Request request) async {
    final payload = jsonDecode(await request.readAsString());
    final usernameOrEmail = payload['username'];
    final password = payload['password'];

    final conn = await DB.getConnection();
    
    // Check if the input is an email format
    bool isEmail = usernameOrEmail.contains('@');
    
    var result;
    if (isEmail) {
      // If it's an email, join users and employees tables to find by email
      result = await conn.execute(
        '''SELECT u.id, u.username, u.password, u.role, e.nom, e.prenom 
           FROM users u 
           JOIN employees e ON u.id = e.user_id 
           WHERE e.email = :email''',
        {'email': usernameOrEmail},
      );
    } else {
      // If it's not an email, use username as before
      result = await conn.execute(
        'SELECT u.id, u.username, u.password, u.role, e.nom, e.prenom FROM users u JOIN employees e ON u.id = e.user_id WHERE u.username = :user',
        {'user': usernameOrEmail},
      );
    }

    if (result.rows.isEmpty) {
      return Response.forbidden(jsonEncode({'error': 'User not found'}));
    }

    final row = result.rows.first;
    final dbPassword = row.assoc()['password'];

    // In production, use password hashing (e.g., bcrypt)
    // For now, comparing plain text as requested in setup
    if (password != dbPassword) {
      return Response.forbidden(jsonEncode({'error': 'Invalid password'}));
    }

    final jwt = JWT({
      'id': row.assoc()['id'],
      'username': row.assoc()['username'],
      'role': row.assoc()['role'],
    });

    final token = jwt.sign(SecretKey(jwtSecret));

    return Response.ok(jsonEncode({
      'token': token,
      'user': {
        'id': row.assoc()['id'],
        'username': row.assoc()['username'],
        'role': row.assoc()['role'],
        'nom': row.assoc()['nom'],
        'prenom': row.assoc()['prenom'],
      }
    }));
  });

  // Reset Request Endpoint
  router.post('/reset-request', (Request request) async {
    final payload = jsonDecode(await request.readAsString());
    final email = payload['email'];

    final conn = await DB.getConnection();
    final userCheck = await conn.execute(
      'SELECT id FROM employees WHERE email = :email',
      {'email': email},
    );

    if (userCheck.rows.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'Email not registered'}));
    }

    final code = (Random().nextInt(900000) + 100000).toString();
    final expiry = DateTime.now().add(Duration(minutes: 15));

    await conn.execute(
      'INSERT INTO password_resets (email, code, expires_at) VALUES (:email, :code, :expires)',
      {
        'email': email,
        'code': code,
        'expires': expiry.toIso8601String().replaceFirst('T', ' ').split('.')[0],
      },
    );

    print('SIMULATED EMAIL to $email: Your reset code is $code');

    return Response.ok(jsonEncode({'message': 'Reset code sent (simulated)'}));
  });

  // Reset Confirm Endpoint
  router.post('/reset-confirm', (Request request) async {
    final payload = jsonDecode(await request.readAsString());
    final email = payload['email'];
    final code = payload['code'];
    final newPassword = payload['password'];

    final conn = await DB.getConnection();
    final result = await conn.execute(
      'SELECT id FROM password_resets WHERE email = :email AND code = :code AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1',
      {'email': email, 'code': code},
    );

    if (result.rows.isEmpty) {
      return Response.forbidden(jsonEncode({'error': 'Invalid or expired code'}));
    }

    // Update password in users table linked to this employee email
    await conn.execute(
      'UPDATE users u JOIN employees e ON u.id = e.user_id SET u.password = :pwd WHERE e.email = :email',
      {'pwd': newPassword, 'email': email},
    );

    // Clean up codes
    await conn.execute('DELETE FROM password_resets WHERE email = :email', {'email': email});

    return Response.ok(jsonEncode({'message': 'Password updated successfully'}));
  });

  // ====== EMPLOYEE ENDPOINTS ======

  // Get all employees
  router.get('/employees', (Request request) async {
    final result = await EmployeeService.getAllEmployees();
    
    if (result['success']) {
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    }
    
    return Response.internalServerError(
      body: jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Get employee by ID
  router.get('/employees/<id>', (Request request, String id) async {
    final result = await EmployeeService.getEmployeeById(id);
    
    if (result['success']) {
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    }
    
    return Response.notFound(
      jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Create new employee (auto-creates user account with @ForeverSoftware2026)
  router.post('/employees', (Request request) async {
    final payload = jsonDecode(await request.readAsString());
    final result = await EmployeeService.createEmployee(payload);
    
    if (result['success']) {
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    }
    
    return Response.internalServerError(
      body: jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Update employee
  router.put('/employees/<id>', (Request request, String id) async {
    final payload = jsonDecode(await request.readAsString());
    final result = await EmployeeService.updateEmployee(id, payload);
    
    if (result['success']) {
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    }
    
    return Response.internalServerError(
      body: jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Delete employee (cascades to user account)
  router.delete('/employees/<id>', (Request request, String id) async {
    final result = await EmployeeService.deleteEmployee(id);
    
    if (result['success']) {
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    }
    
    return Response.internalServerError(
      body: jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  });


  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router);

  final server = await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Backend server listening on port ${server.port}');
}
