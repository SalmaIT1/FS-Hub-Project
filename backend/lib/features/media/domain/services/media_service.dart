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
    return filename
        .replaceAll('/', '')
        .replaceAll('\\', '')
        .replaceAll('..', '');
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
}
