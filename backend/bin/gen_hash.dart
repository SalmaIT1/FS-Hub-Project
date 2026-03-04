import 'package:bcrypt/bcrypt.dart';

void main() {
  print(BCrypt.hashpw('@ForeverSoftware2026', BCrypt.gensalt()));
}
