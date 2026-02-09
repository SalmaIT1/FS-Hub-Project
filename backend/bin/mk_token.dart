import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

void main(List<String> args) {
  final userId = args.isNotEmpty ? args[0] : '2';
  final expirySeconds = 60 * 60 * 24;
  final jwt = JWT({
    'userId': userId,
    'role': 'Employé',
    'exp': DateTime.now().add(Duration(seconds: expirySeconds)).millisecondsSinceEpoch ~/ 1000,
  });

  final token = jwt.sign(SecretKey(''));
  print(token);
}
