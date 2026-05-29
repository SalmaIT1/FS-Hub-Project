/// Login form validators (unit-testable without widget tree).
class LoginValidators {
  LoginValidators._();

  static String? username(String? value, {String emptyMessage = 'Required'}) {
    if (value == null || value.trim().isEmpty) return emptyMessage;
    return null;
  }

  static String? password(String? value, {String emptyMessage = 'Required'}) {
    if (value == null || value.isEmpty) return emptyMessage;
    return null;
  }
}
