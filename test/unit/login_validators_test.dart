import 'package:flutter_test/flutter_test.dart';
import 'package:fs_hub/core/validation/login_validators.dart';

void main() {
  group('LoginValidators — login form', () {
    test('username required', () {
      expect(LoginValidators.username(''), isNotNull);
      expect(LoginValidators.username('  '), isNotNull);
      expect(LoginValidators.username('admin'), isNull);
    });

    test('password required', () {
      expect(LoginValidators.password(''), isNotNull);
      expect(LoginValidators.password('secret'), isNull);
    });
  });
}
