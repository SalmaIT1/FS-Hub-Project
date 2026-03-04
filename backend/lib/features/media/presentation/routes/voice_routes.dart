import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/media_service.dart';

class VoiceRoutes {
  late final Router router;

  VoiceRoutes() {
    router = Router()
      ..get('/', _serveVoiceFile)
      ..get('/<filename>', _serveVoiceFile);
  }

  Future<Response> _serveVoiceFile(Request request, [String? filename]) async {
    try {
      final uploadsDir = Directory('uploads');
      if (!await uploadsDir.exists()) return Response.notFound('Uploads directory not found');

      if (filename == null || filename.isEmpty) {
        return Response.ok(
          'Voice files endpoint. Use /voice/<filename> to access specific files.',
          headers: {'Content-Type': 'text/plain'},
        );
      }

      final sanitized = MediaService.sanitizeFilename(filename);
      final allowedExtensions = ['.wav', '.m4a', '.aac', '.mp3', '.ogg'];
      final hasAllowedExtension = allowedExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
      if (!hasAllowedExtension) return Response.forbidden('File type not allowed');

      final filePath = '${uploadsDir.path}/$sanitized';
      final file = File(filePath);
      if (!await file.exists()) return Response.notFound('Voice file not found: $filename');

      final extension = sanitized.split('.').last;
      final contentType = MediaService.getCorrectMimeType(extension);
      final fileBytes = await file.readAsBytes();

      return Response.ok(
        fileBytes,
        headers: {
          'Content-Type': contentType,
          'Content-Length': fileBytes.length.toString(),
          'Cache-Control': 'public, max-age=3600',
          'Accept-Ranges': 'bytes',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Error: $e'}));
    }
  }
}
