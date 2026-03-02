// Stub for non-web platforms. html.HttpRequest is never called on non-web
// (all usages are guarded by `kIsWeb` checks), so empty stubs are sufficient.
class HttpRequest {
  static Future<HttpRequest> request(
    String url, {
    String? method,
    String? responseType,
  }) async {
    throw UnsupportedError('dart:html is not available on this platform');
  }

  int get status => 0;
  dynamic get response => null;
}
