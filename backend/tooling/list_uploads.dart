import 'package:dotenv/dotenv.dart' as dotenv;
import '../lib/database/db_connection.dart';

Future<void> main(List<String> args) async {
  try {
    await DBConnection.initialize();
    final conn = DBConnection.getConnection();
    final res = await conn.execute('SELECT id, stored_filename, file_path, mime_type FROM file_uploads WHERE stored_filename LIKE :pat OR file_path LIKE :pat LIMIT 50', {'pat': '%10%'});
    if (res.rows.isEmpty) {
      print('No matching uploads found');
    } else {
      for (final r in res.rows) {
        print('id=${r.colByName('id')}, stored_filename=${r.colByName('stored_filename')}, file_path=${r.colByName('file_path')}, mime=${r.colByName('mime_type')}');
      }
    }
  } catch (e, st) {
    print('Error querying DB: $e\n$st');
  }
}
