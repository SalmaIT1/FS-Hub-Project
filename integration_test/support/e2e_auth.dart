import 'package:fs_hub/core/security/token_storage.dart';
import 'package:fs_hub/features/auth/data/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clears tokens and cached user before each E2E scenario.
Future<void> resetE2eAuthState() async {
  await TokenStorage.clearTokens();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('user_data');
  await prefs.remove('protocol_version');
}

/// Returns true when the backend login endpoint is reachable.
Future<bool> isBackendReachable() async {
  final result = await AuthService.login('__probe__', '__probe__');
  return result['error'] != null &&
      !result['error'].toString().contains('Failed host lookup') &&
      !result['error'].toString().contains('Connection refused');
}
