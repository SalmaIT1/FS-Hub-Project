import '../services/api_service.dart';

class UrlUtils {
  /// Ensures a URL is absolute by prepending the base URL if needed.
  static String ensureAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // If it's already absolute (http, blob, data), return as is
    if (url.contains('://') || url.startsWith('blob:') || url.startsWith('data:')) {
      return url;
    }
    
    // Normalize path - avoid double slashes
    final baseUrl = ApiService.baseUrl.endsWith('/') 
        ? ApiService.baseUrl.substring(0, ApiService.baseUrl.length - 1) 
        : ApiService.baseUrl;
    
    final cleanPath = url.startsWith('/') ? url : '/$url';
    return '$baseUrl$cleanPath';
  }

  static String normalizeAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    
    // 1. If it's already absolute (http, data, blob), just ensure it's absolute (redundant but safe)
    if (raw.contains('://') || raw.startsWith('data:') || raw.startsWith('blob:')) {
      return raw;
    }
    
    // 2. Handle base64 fallback for long strings without prefix
    if (raw.length > 100 && !raw.startsWith('/')) {
      return 'data:image/jpeg;base64,$raw';
    }
    
    // 3. filename or relative URL — make absolute with /media/ prefix if missing
    final path = raw.startsWith('/') 
        ? (raw.startsWith('/media/') ? raw : '/media$raw') 
        : '/media/$raw';
    return ensureAbsoluteUrl(path);
  }


  /// Appends authentication token to URL as a query parameter.
  static String appendToken(String url, String? token) {
    if (token == null || token.isEmpty || url.isEmpty) return url;
    if (url.startsWith('blob:') || url.startsWith('data:')) return url;
    
    final uri = Uri.parse(url);
    final params = Map<String, dynamic>.from(uri.queryParameters);
    params['token'] = token;
    
    return uri.replace(queryParameters: params).toString();
  }
}
