import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:fs_hub_backend/shared/database/connection.dart';
import 'auth_middleware.dart';

/// Middleware to handle idempotency using the X-Idempotency-Key header.
/// If a request with the same key and user ID exists, the cached response is returned.
Middleware idempotency() {
  return (Handler innerHandler) {
    return (Request request) async {
      final key = request.headers['X-Idempotency-Key'] ?? request.headers['x-idempotency-key'];
      
      // Only apply to mutation methods
      if (key == null || (request.method != 'POST' && request.method != 'PUT' && request.method != 'PATCH')) {
        return innerHandler(request);
      }

      final userId = request.authUserId ?? 'anonymous';
      final db = DBConnection.getConnection();

      try {
        // 1. Check for existing key
        final result = await db.execute(
          'SELECT response_code, response_body FROM idempotency_keys WHERE id = :key AND user_id = :userId',
          {'key': key, 'userId': userId},
        );

        if (result.rows.isNotEmpty) {
          final row = result.rows.first.assoc();
          final code = int.tryParse(row['response_code'].toString()) ?? 200;
          final body = row['response_body']?.toString() ?? '{}';
          
          print('[IDEMPOTENCY] Cache hit for key=$key userId=$userId');
          return Response(
            code,
            body: body,
            headers: {'Content-Type': 'application/json; charset=utf-8', 'X-Idempotency-Cache': 'HIT'},
          );
        }

        // 2. Process request
        final response = await innerHandler(request);

        // 3. Cache response if it was a success (2xx) or valid functional error (4xx)
        // Avoid caching 5xx internal errors to allow retries.
        if (response.statusCode >= 200 && response.statusCode < 500) {
          final body = await response.readAsString();
          
          await db.execute(
            '''INSERT INTO idempotency_keys (id, user_id, response_code, response_body, expires_at)
               VALUES (:key, :userId, :code, :body, DATE_ADD(NOW(), INTERVAL 24 HOUR))''',
            {
              'key': key,
              'userId': userId,
              'code': response.statusCode,
              'body': body,
            },
          );

          // Return a new response because the original body stream was consumed
          return response.change(body: body);
        }

        return response;
      } catch (e) {
        print('[IDEMPOTENCY] Error: $e');
        return innerHandler(request);
      }
    };
  };
}
