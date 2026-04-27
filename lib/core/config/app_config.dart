class AppConfig {
  static const String apiBaseUrl = 'https://raegan-iridous-ernie.ngrok-free.dev';

  static String get apiV1BaseUrl => '$apiBaseUrl/v1';

  static String get wsBaseUrl {
    final override = const String.fromEnvironment('WS_BASE_URL', defaultValue: '');
    if (override.isNotEmpty) return override;

    final wsScheme = apiBaseUrl.startsWith('https://') ? 'wss://' : 'ws://';
    final host = apiBaseUrl.replaceFirst(RegExp(r'^https?:\/\/'), '');
    return '$wsScheme$host/ws';
  }

  static const String protocolVersion = '1.1';
}
