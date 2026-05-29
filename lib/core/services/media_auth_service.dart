import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fs_hub/core/config/app_config.dart';
import 'package:fs_hub/core/security/token_storage.dart';

/// Fetches short-lived one-time tickets for /media/* URLs (replaces JWT in query).
class MediaAuthService {
  static final Map<String, _CachedTicket> _cache = {};

  static Future<String?> ticketForMediaUrl(String absoluteUrl) async {
    final filename = _extractStoredFilename(absoluteUrl);
    if (filename.isEmpty) return null;

    final cached = _cache[filename];
    if (cached != null && !cached.isExpired) return cached.ticket;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiV1BaseUrl}/auth/media-ticket'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'filename': filename}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final ticket = body['ticket']?.toString();
        if (ticket != null && ticket.isNotEmpty) {
          _cache[filename] = _CachedTicket(ticket);
          return ticket;
        }
      }
    } catch (_) {}
    return null;
  }

  static String _extractStoredFilename(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      const prefix = '/media/';
      final idx = path.indexOf(prefix);
      if (idx >= 0) {
        return Uri.decodeComponent(path.substring(idx + prefix.length));
      }
      if (path.startsWith('media/')) {
        return Uri.decodeComponent(path.substring(6));
      }
    } catch (_) {}
    return '';
  }
}

class _CachedTicket {
  final String ticket;
  final DateTime expiresAt;
  _CachedTicket(this.ticket) : expiresAt = DateTime.now().add(const Duration(minutes: 4));
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
