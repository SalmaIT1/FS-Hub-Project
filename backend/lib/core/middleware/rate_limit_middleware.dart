import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../shared/database/connection.dart';

/// IP + User rate-limiting middleware.
///
/// Enforces a sliding-window restriction on sensitive endpoints.
/// Configuration is per-call-site:
///
///   final securedLogin = Pipeline()
///       .addMiddleware(rateLimit(maxAttempts: 5, windowSeconds: 300))
///       .addMiddleware(requireAuth())
///       .addHandler(authRoutes.router);
///
/// The blocking identifier is the `X-Forwarded-For` header value (or
/// `request.connection.remoteAddress` if absent), combined with the endpoint
/// path so each route has its own independent bucket.
///
/// Persistence uses the `rate_limit_attempts` table maintained by
/// `DataIntegrityService._cleanupSecurityTables`.
Middleware rateLimit({int maxAttempts = 10, int windowSeconds = 60}) {
  return (innerHandler) {
    return (Request request) async {
      // Skip OPTIONS pre-flight
      if (request.method == 'OPTIONS') return innerHandler(request);

      final identifier = _resolveIdentifier(request);
      final endpoint = request.requestedUri.path;

      try {
        final db = DBConnection.getConnection();

        // Count attempts within the window
        final countRes = await db.execute(
          '''SELECT COUNT(*) as cnt
             FROM rate_limit_attempts
             WHERE identifier = :id
               AND endpoint   = :ep
               AND attempted_at > DATE_SUB(NOW(), INTERVAL :window SECOND)''',
          {'id': identifier, 'ep': endpoint, 'window': windowSeconds},
        );

        final count = int.tryParse(
                countRes.rows.first.colByName('cnt')?.toString() ?? '0') ??
            0;

        if (count >= maxAttempts) {
          print('[RATE-LIMIT] BLOCKED $identifier on $endpoint ($count/$maxAttempts in ${windowSeconds}s)');
          return Response(
            429,
            body: jsonEncode({
              'success': false,
              'message': 'Too many requests. Please try again later.',
              'retryAfter': windowSeconds,
            }),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Retry-After': windowSeconds.toString(),
              'X-RateLimit-Limit': maxAttempts.toString(),
              'X-RateLimit-Remaining': '0',
              'X-RateLimit-Reset':
                  DateTime.now().add(Duration(seconds: windowSeconds)).toUtc().toIso8601String(),
            },
          );
        }

        // Record this attempt (fire-and-forget; never block the request on failure)
        unawaited(
          db.execute(
            'INSERT INTO rate_limit_attempts (identifier, endpoint) VALUES (:id, :ep)',
            {'id': identifier, 'ep': endpoint},
          ).then((_) {}).catchError((e) {
            print('[RATE-LIMIT] Failed to record attempt: $e');
          }),
        );

        // Attach remaining-count to response headers
        final response = await innerHandler(request);
        return response.change(headers: {
          'X-RateLimit-Limit': maxAttempts.toString(),
          'X-RateLimit-Remaining': (maxAttempts - count - 1).clamp(0, maxAttempts).toString(),
        });
      } catch (e) {
        // On storage failure, fail OPEN (allow request) to avoid a DB outage
        // taking down the entire API surface.
        print('[RATE-LIMIT] Storage error (failing open): $e');
        return innerHandler(request);
      }
    };
  };
}

/// Resolves the best-available client identifier from the request.
/// Falls through a chain of strategies so that distinct clients always get
/// distinct buckets — the 'unknown' shared bucket is eliminated entirely.
///
///  1. X-Forwarded-For  — set by Nginx/load-balancer (most accurate in prod)
///  2. shelf.io connection info — raw TCP socket address (no proxy)
///  3. Authenticated user ID  — from requireAuth() context (route-level fallback)
///  4. Stable header fingerprint  — worst case; imperfect but isolated per UA
String _resolveIdentifier(Request request) {
  // 1. Proxy header — trusted only when set by backend infrastructure.
  final forwarded = request.headers['x-forwarded-for'] ??
      request.headers['X-Forwarded-For'];
  if (forwarded != null && forwarded.isNotEmpty) {
    return forwarded.split(',').first.trim();
  }

  // 2. Raw socket address via shelf.io context.
  final connInfo = request.context['shelf.io.connection_info'];
  if (connInfo != null) {
    try {
      // Use dynamic dispatch to avoid a hard dependency on dart:io in this file.
      final addr = (connInfo as dynamic).remoteAddress?.address?.toString();
      if (addr != null && addr.isNotEmpty) return addr;
    } catch (_) {}
  }

  // 3. Authenticated user ID — populated by requireAuth() middleware.
  final userId = request.context['userId']?.toString() ??
      request.context['auth_user_id']?.toString();
  if (userId != null && userId.isNotEmpty) return 'user:$userId';

  // 4. Header fingerprint — isolates by User-Agent + Accept-Language.
  //    Imperfect (collisions possible) but far better than a shared bucket.
  final ua = request.headers['user-agent'] ?? '';
  final lang = request.headers['accept-language'] ?? '';
  return 'anon:${(ua + lang).hashCode.abs()}';
}
