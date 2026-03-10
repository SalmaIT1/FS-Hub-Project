import 'dart:convert';
import 'package:http/http.dart' as http;

class RESTFallbackClient {
  final String baseUrl;
  final Future<String> Function() tokenProvider;

  RESTFallbackClient({required this.baseUrl, required this.tokenProvider});

  Future<Map<String, String>> _getHeaders() async => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${await tokenProvider()}',
  };

  Future<HttpResponse> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      return HttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw Exception('GET request failed: $e');
    }
  }

  Future<HttpResponse> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      return HttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw Exception('POST request failed: $e');
    }
  }

  Future<HttpResponse> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      return HttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw Exception('PUT request failed: $e');
    }
  }

  Future<HttpResponse> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      return HttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      throw Exception('DELETE request failed: $e');
    }
  }
}

class HttpResponse {
  final int statusCode;
  final String? body;
  final Map<String, String> headers;

  HttpResponse({
    required this.statusCode,
    this.body,
    required this.headers,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;
}
