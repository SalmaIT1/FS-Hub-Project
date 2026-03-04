import 'dart:convert';
import 'package:http/http.dart' as http;

class RESTFallbackClient {
  final String baseUrl;
  final Future<String> Function() tokenProvider;

  RESTFallbackClient({required this.baseUrl, required this.tokenProvider});

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final token = await tokenProvider();
    // Normalize path to avoid duplicate '/v1' when callers include it and
    // `baseUrl` already contains '/v1'. This preserves existing caller
    // behavior while preventing requests to '/v1/v1/...'.
    var normalizedPath = path;
    if (baseUrl.endsWith('/v1') && path.startsWith('/v1')) {
      normalizedPath = path.substring(3); // remove leading '/v1'
    }
    final res = await http.post(Uri.parse('$baseUrl$normalizedPath'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token'
        },
        body: jsonEncode(body));
    return res;
  }

  Future<http.Response> get(String path) async {
    final token = await tokenProvider();
    var normalizedPath = path;
    if (baseUrl.endsWith('/v1') && path.startsWith('/v1')) {
      normalizedPath = path.substring(3);
    }
    return http.get(Uri.parse('$baseUrl$normalizedPath'), headers: {'authorization': 'Bearer $token'});
  }
}
