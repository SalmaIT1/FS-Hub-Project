import '../config/app_config.dart';

class UrlUtils {
  static String get _baseUrl {
    final base = AppConfig.apiBaseUrl;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  static String ensureAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    if (url.contains('://') || url.startsWith('blob:') || url.startsWith('data:')) {
      return url;
    }

    final bool isWindowsPath = url.contains(':\\');
    final bool isLocalUnixPath = url.startsWith('/') &&
        !url.startsWith('/v1/') &&
        !url.startsWith('/media/') &&
        !url.startsWith('/auth/');

    if (isWindowsPath || isLocalUnixPath) {
      return url;
    }

    final cleanPath = url.startsWith('/') ? url : '/$url';
    return '$_baseUrl$cleanPath';
  }

  static String normalizeAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';

    if (raw.contains('://') || raw.startsWith('data:') || raw.startsWith('blob:')) {
      return raw;
    }

    final cleanedRaw = raw.replaceAll(RegExp(r'\s+'), '');
    if (cleanedRaw.length > 200) {
      return 'data:image/jpeg;base64,$cleanedRaw';
    }

    final path = raw.startsWith('/')
        ? (raw.startsWith('/media/') ? raw : '/media$raw')
        : '/media/$raw';
    return ensureAbsoluteUrl(path);
  }

  /// Appends a one-time media ticket (from /auth/media-ticket).
  static String appendMediaTicket(String url, String? ticket) {
    if (ticket == null || ticket.isEmpty || url.isEmpty) return url;
    if (url.startsWith('blob:') || url.startsWith('data:')) return url;

    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params.remove('token');
    params['media_ticket'] = ticket;
    return uri.replace(queryParameters: params).toString();
  }

  @Deprecated('Use MediaAuthService + appendMediaTicket instead of JWT in URLs')
  static String appendToken(String url, String? token) {
    if (token == null || token.isEmpty || url.isEmpty) return url;
    if (url.startsWith('blob:') || url.startsWith('data:')) return url;

    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['token'] = token;
    return uri.replace(queryParameters: params).toString();
  }
}
