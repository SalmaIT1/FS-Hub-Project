import '../lib/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final db = DBConnection.getConnection();
  try {
     await db.execute("ALTER TABLE clients ADD COLUMN credit DOUBLE NOT NULL DEFAULT 0.0");
     print("Added credit column to clients.");
  } catch(e) { print(e); }
  print("done");
}
