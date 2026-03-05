import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/media_service.dart';
import '../../../../core/middleware/auth_middleware.dart';

const int _maxUploadBytes = 50 * 1024 * 1024;
const Set<String> _allowedExtensions = {
  'jpg', 'jpeg', 'png', 'gif', 'webp',
  'mp3', 'wav', 'ogg', 'aac', 'm4a', 'webm',
  'mp4', 'pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx',
};

class UploadRoutes {
  late final Router router;

  UploadRoutes() {
    router = Router()
      ..post('/', _uploadFile)
      ..post('/signed-url', _getSignedUrl)
      ..put('/<uploadId>/put', _putUpload)
      ..post('/complete', _completeUpload)
      ..get('/<uploadId>', _getUploadStatus);
  }

  Future<Response> _putUpload(Request request, String uploadId) async {
    try {
      final userId = request.authUserId;
      final media = await MediaService.getMediaById(uploadId);
      if (media == null) return Response.notFound(jsonEncode({'success': false, 'message': 'Not found'}));
      if (media.uploadedBy != userId) return Response.forbidden(jsonEncode({'success': false, 'message': 'Forbidden'}));

      final uploadDir = Directory('uploads');
      if (!await uploadDir.exists()) await uploadDir.create(recursive: true);

      final extension = media.storedFilename.contains('.') ? media.storedFilename.split('.').last : 'bin';
      final actualStoredFilename = '$uploadId.$extension';
      final filePath = '${uploadDir.path}/$actualStoredFilename';

      // SECURE STREAMING: Read request stream and write directly to disk to avoid Memory DoS
      final file = File(filePath);
      final sink = file.openWrite();
      int totalBytes = 0;
      
      try {
        await for (final chunk in request.read()) {
          totalBytes += chunk.length;
          if (totalBytes > _maxUploadBytes) {
             await sink.close();
             if (await file.exists()) await file.delete();
             return Response(413, body: jsonEncode({'success': false, 'message': 'File too large'}));
          }
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }

      await MediaService.updateMedia(uploadId, {
        'stored_filename': actualStoredFilename,
        'file_path': filePath,
        'file_size': totalBytes,
      });

      return Response.ok(jsonEncode({'success': true, 'upload_id': uploadId}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Upload failed: $e'}));
    }
  }

  Future<Response> _uploadFile(Request request) async {
    // This handler uses MimeMultipartTransformer which also streams,
    // but we ensure we don't buffer the whole thing in memory.
    try {
      final userId = request.authUserId;
      final contentType = request.headers['content-type'] ?? '';
      if (!contentType.contains('multipart/form-data')) {
        return Response.badRequest(body: jsonEncode({'success': false, 'message': 'multipart/form-data required'}));
      }

      final boundaryMatch = RegExp(r'boundary=(.+)$').firstMatch(contentType);
      if (boundaryMatch == null) return Response.badRequest(body: jsonEncode({'success': false, 'message': 'Missing boundary'}));
      final boundary = boundaryMatch.group(1)!.trim();

      final transformer = MimeMultipartTransformer(boundary);
      final parts = transformer.bind(request.read()); // Stream from request directly

      String? filename;
      String? mimeType;
      String? uploadId;
      String? filePath;
      int totalBytes = 0;

      await for (final part in parts) {
        final disposition = part.headers['content-disposition'] ?? '';
        if (disposition.contains('filename=')) {
          final fnMatch = RegExp(r'filename="([^"]*)"').firstMatch(disposition);
          if (fnMatch != null) filename = MediaService.sanitizeFilename(fnMatch.group(1)!);
          mimeType = part.headers['content-type']?.trim();
          
          final extension = filename!.contains('.') ? filename.split('.').last.toLowerCase() : 'bin';
          if (!_allowedExtensions.contains(extension)) {
            return Response(415, body: jsonEncode({'success': false, 'message': 'File extension not allowed'}));
          }

          // Create record pending
          final newId = await MediaService.insertMedia({
            'original_filename': filename,
            'stored_filename': 'pending',
            'file_path': 'pending',
            'file_size': 0,
            'mime_type': mimeType ?? 'application/octet-stream',
            'uploaded_by': userId,
            'is_public': false,
            'expires_at': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
          });
          uploadId = newId.toString();

          final uploadDir = Directory('uploads');
          if (!await uploadDir.exists()) await uploadDir.create(recursive: true);
          
          final actualStoredFilename = '$uploadId.$extension';
          filePath = '${uploadDir.path}/$actualStoredFilename';
          final file = File(filePath);
          final sink = file.openWrite();

          try {
            await for (final chunk in part) {
              totalBytes += chunk.length;
              if (totalBytes > _maxUploadBytes) {
                await sink.close();
                if (await file.exists()) await file.delete();
                return Response(413, body: jsonEncode({'success': false, 'message': 'File too large'}));
              }
              sink.add(chunk);
            }
          } finally {
            await sink.close();
          }

          if (mimeType != null && mimeType.startsWith('image/')) {
             await MediaService.generateThumbnail(filePath, uploadId.toString());
          }

          await MediaService.updateMedia(uploadId.toString(), {
            'stored_filename': actualStoredFilename,
            'file_path': filePath,
            'file_size': totalBytes,
          });
        }
      }

      if (uploadId == null) {
        return Response.badRequest(body: jsonEncode({'success': false, 'message': 'No file found'}));
      }

      return Response.ok(jsonEncode({
        'success': true,
        'upload_id': uploadId,
        'original_filename': filename,
        'file_size': totalBytes,
        'mime_type': mimeType,
      }));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Upload failed: $e'}));
    }
  }

  Future<Response> _getSignedUrl(Request request) async {
    try {
      final userId = request.authUserId;
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final filename = data['filename']?.toString();
      final mimeType = data['mime']?.toString();
      final fileSize = int.tryParse(data['size']?.toString() ?? '0') ?? 0;

      if (filename == null || mimeType == null || fileSize <= 0 || fileSize > _maxUploadBytes) {
        return Response.badRequest(body: jsonEncode({'success': false, 'message': 'Invalid parameters'}));
      }

      final safeFilename = MediaService.sanitizeFilename(filename);
      final extension = safeFilename.contains('.') ? safeFilename.split('.').last.toLowerCase() : 'bin';

      if (!_allowedExtensions.contains(extension)) {
        return Response(415, body: jsonEncode({'success': false, 'message': 'File extension not allowed'}));
      }

      final expiresAt = DateTime.now().add(const Duration(minutes: 15));
      final uploadId = await MediaService.insertMedia({
        'original_filename': safeFilename,
        'stored_filename': 'pending.$extension',
        'file_path': 'pending',
        'file_size': fileSize,
        'mime_type': mimeType,
        'uploaded_by': userId,
        'is_public': false,
        'expires_at': expiresAt.toIso8601String(),
      });

      await MediaService.updateMedia(uploadId.toString(), {
        'stored_filename': '$uploadId.$extension',
        'file_path': 'uploads/$uploadId.$extension',
      });

      final baseUrl = '${request.requestedUri.scheme}://${request.requestedUri.host}:${request.requestedUri.port}';
      return Response.ok(jsonEncode({
        'success': true,
        'upload_id': uploadId,
        'upload_url': '$baseUrl/v1/uploads/$uploadId/put',
        'expires_at': expiresAt.toIso8601String(),
      }));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Failed to create upload slot'}));
    }
  }

  Future<Response> _completeUpload(Request request) async {
    try {
      final userId = request.authUserId;
      final data = jsonDecode(await request.readAsString());
      final uploadId = data['upload_id']?.toString();
      if (uploadId == null) return Response.badRequest(body: jsonEncode({'success': false, 'message': 'upload_id is required'}));

      final media = await MediaService.getMediaById(uploadId);
      if (media == null) return Response.notFound(jsonEncode({'success': false, 'message': 'Not found'}));
      if (media.uploadedBy != userId) return Response.forbidden(jsonEncode({'success': false, 'message': 'Forbidden'}));

      if (!await File(media.filePath).exists()) {
        return Response(422, body: jsonEncode({'success': false, 'message': 'File not yet uploaded'}));
      }

      await MediaService.setExpiry(uploadId, DateTime.now().add(const Duration(days: 365)).toIso8601String());

      final baseUrl = '${request.requestedUri.scheme}://${request.requestedUri.host}:${request.requestedUri.port}';
      return Response.ok(jsonEncode({
        'success': true,
        'upload_id': uploadId,
        'file_url': '$baseUrl/media/${media.storedFilename}',
      }));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Complete upload failed'}));
    }
  }

  Future<Response> _getUploadStatus(Request request, String uploadId) async {
    try {
      final userId = request.authUserId;
      final media = await MediaService.getMediaById(uploadId);
      if (media == null) return Response.notFound(jsonEncode({'success': false, 'message': 'Not found'}));

      if (!media.isPublic && media.uploadedBy != userId) {
        return Response.forbidden(jsonEncode({'success': false, 'message': 'Forbidden'}));
      }

      return Response.ok(jsonEncode({
        'success': true,
        ...media.toJson(),
      }));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Failed to get upload'}));
    }
  }
}
