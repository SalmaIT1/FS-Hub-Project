import '../../../../shared/database/connection.dart';
import '../models/media_model.dart';

class MediaRepository {
  final _db = DBConnection.getConnection();

  Future<MediaModel?> getMediaById(String id) async {
    final result = await _db.execute(
      '''SELECT id, original_filename, stored_filename, file_path, file_size,
                mime_type, uploaded_by, is_public, download_count, created_at, expires_at
         FROM file_uploads WHERE id = :id''',
      {'id': id},
    );
    if (result.rows.isEmpty) return null;
    return MediaModel.fromMap(result.rows.first.assoc());
  }

  Future<MediaModel?> getMediaByStoredFilename(String storedFilename) async {
    final result = await _db.execute(
      '''SELECT id, original_filename, stored_filename, file_path, file_size,
                mime_type, uploaded_by, is_public, download_count, created_at, expires_at
         FROM file_uploads WHERE stored_filename = :storedFilename''',
      {'storedFilename': storedFilename},
    );
    if (result.rows.isEmpty) return null;
    return MediaModel.fromMap(result.rows.first.assoc());
  }

  Future<int> insertMedia(Map<String, dynamic> data) async {
    final result = await _db.execute(
      '''INSERT INTO file_uploads (
           original_filename, stored_filename, file_path, file_size,
           mime_type, uploaded_by, is_public, download_count, created_at, expires_at
         ) VALUES (
           :originalFilename, :storedFilename, :filePath, :fileSize,
           :mimeType, :uploadedBy, :isPublic, :downloadCount, NOW(), :expiresAt
         )''',
      {
        'originalFilename': data['original_filename'],
        'storedFilename': data['stored_filename'],
        'filePath': data['file_path'],
        'fileSize': data['file_size'],
        'mimeType': data['mime_type'],
        'uploadedBy': data['uploaded_by'],
        'isPublic': data['is_public'] ? 1 : 0,
        'downloadCount': 0,
        'expiresAt': data['expires_at'],
      },
    );
    return result.lastInsertID.toInt();
  }

  Future<void> updateMedia(String id, Map<String, dynamic> data) async {
    String query = 'UPDATE file_uploads SET ';
    final List<String> sets = [];
    final Map<String, dynamic> params = {'id': id};

    if (data.containsKey('stored_filename')) {
      sets.add('stored_filename = :stored_filename');
      params['stored_filename'] = data['stored_filename'];
    }
    if (data.containsKey('file_path')) {
      sets.add('file_path = :file_path');
      params['file_path'] = data['file_path'];
    }
    if (data.containsKey('file_size')) {
      sets.add('file_size = :file_size');
      params['file_size'] = data['file_size'];
    }
    if (data.containsKey('expires_at')) {
      sets.add('expires_at = :expires_at');
      params['expires_at'] = data['expires_at'];
    }

    if (sets.isEmpty) return;
    query += '${sets.join(', ')} WHERE id = :id';
    await _db.execute(query, params);
  }

  Future<void> setExpiry(String id, String expiresAt) async {
    await _db.execute(
      'UPDATE file_uploads SET expires_at = :expiresAt WHERE id = :id',
      {'expiresAt': expiresAt, 'id': id},
    );
  }
}
