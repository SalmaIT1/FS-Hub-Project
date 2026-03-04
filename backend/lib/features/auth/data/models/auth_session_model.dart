import 'user_model.dart';

class AuthSessionModel {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  AuthSessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }
}
