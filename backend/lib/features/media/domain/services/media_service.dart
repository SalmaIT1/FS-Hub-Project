import 'dart:io';
import '../../data/repositories/media_repository.dart';
import '../../data/models/media_model.dart';

class MediaService {
  static final _repository = MediaRepository();

  static Future<MediaModel?> getMediaById(String id) async {
    return await _repository.getMediaById(id);
  }

  static Future<MediaModel?> getMediaByStoredFilename(String storedFilename) async {
    return await _repository.getMediaByStoredFilename(storedFilename);
  }

  static Future<int> insertMedia(Map<String, dynamic> data) async {
    return await _repository.insertMedia(data);
  }

  static Future<void> updateMedia(String id, Map<String, dynamic> data) async {
    await _repository.updateMedia(id, data);
  }

  static Future<void> setExpiry(String id, String expiresAt) async {
    await _repository.setExpiry(id, expiresAt);
  }

  static String sanitizeFilename(String filename) {
    // M-3 FIX: Strip null bytes, control characters, path separators,
    // and other dangerous characters. Then collapse double-dots.
    return filename
        .replaceAll(RegExp(r'[\x00-\x1F\x7F/\\?%*:|"<>]'), '_') // control chars + dangerous chars
        .replaceAll('..', '')   // prevent path traversal like ../../etc
        .trim();
  }

  static String getCorrectMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'aac': return 'audio/aac';
      case 'm4a': return 'audio/mp4';
      case 'mp4': return 'video/mp4';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'ogg': return 'audio/ogg';
      case 'webm': return 'audio/webm';
      case 'pdf': return 'application/pdf';
      case 'png': return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      default: return 'application/octet-stream';
    }
  }

  static Future<String?> generateThumbnail(String imagePath, String uploadId) async {
    try {
      final thumbnailDir = Directory('uploads/thumbnails');
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }
      final thumbnailPath = '${thumbnailDir.path}/${uploadId}_thumb.jpg';
      final originalFile = File(imagePath);
      if (await originalFile.exists()) {
        await originalFile.copy(thumbnailPath);
        return thumbnailPath;
      }
      return null;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  static Future<File?> resolveFile(MediaModel media) async {
    final file = File(media.filePath);
    if (await file.exists()) return file;

    final parent = file.parent;
    final tryPath = '${parent.path}/${media.storedFilename}';
    final tryFile = File(tryPath);
    if (await tryFile.exists()) return tryFile;

    return null;
  }

  /// H-6 FIX: Determine if a user is allowed to access the specified media.
  static Future<bool> canAccessMedia({
    required MediaModel media,
    required String userId,
    required bool isAdmin,
  }) async {
    // 1. Truly public media is accessible by all authenticated users.
    if (media.isPublic) return true;

    // 2. Administrators can access anything.
    if (isAdmin) return true;

    // 3. The original uploader can access their own private files.
    if (media.uploadedBy == userId) return true;

    // 4. If the file is attached to a message, anyone in that conversation can see it.
    // This allows chat attachments (which are private) to be seen by recipients.
    final checkRes = await _repository.checkIfFileInUserConversations(media.storedFilename, userId);
    return checkRes;
  }
}
