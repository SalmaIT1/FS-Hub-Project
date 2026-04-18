import '../lib/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final db = DBConnection.getConnection();
  
  List<String> alters = [
    "ALTER TABLE clients ADD COLUMN matricule_fiscale VARCHAR(255) NULL",
    "ALTER TABLE clients ADD COLUMN adresse TEXT NULL",
    "ALTER TABLE clients ADD COLUMN patente_document TEXT NULL",
    "ALTER TABLE clients ADD COLUMN user_id VARCHAR(36) NULL"
  ];
  
  for (var sql in alters) {
    try {
      await db.execute(sql);
      print('Ran: $sql');
    } catch(e) {
      print('Skipped or failed: $sql -> $e');
    }
  }
  print('done');
}
