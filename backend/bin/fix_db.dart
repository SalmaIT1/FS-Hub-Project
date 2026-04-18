import '../lib/shared/database/connection.dart';

void main() async {
  await DBConnection.initialize();
  final db = DBConnection.getConnection();
  try {
    var res = await db.execute("DESCRIBE users");
    print('Users columns:');
    for (var r in res.rows) {
      print(r.colAt(0)); // Print column name
    }
  } catch(e) { print(e); }
  
  try {
     print('Adding document columns...');
     await db.execute("ALTER TABLE employees ADD COLUMN cin_document TEXT NULL, ADD COLUMN cv_document TEXT NULL, ADD COLUMN bac_document TEXT NULL, ADD COLUMN degree_document TEXT NULL, ADD COLUMN transcripts_documents TEXT NULL");
     print('Done adding columns');
  } catch(e) { 
     print('Error adding columns: $e'); 
  }
  
  print('done');
}
