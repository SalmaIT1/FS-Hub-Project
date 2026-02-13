import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/auth_service.dart';
import '../database/db_connection.dart';

class VoiceRoutes {
  late final Router router;

  VoiceRoutes() {
    router = Router()
      ..get('/', _serveVoiceFile)
      ..get('/<filename>', _serveVoiceFile);
  }

  /// Serve voice files from uploads directory
  Future<Response> _serveVoiceFile(Request request, [String? filename]) async {
    try {
      final uploadsDir = Directory('uploads');
      if (!await uploadsDir.exists()) {
        return Response.notFound('Uploads directory not found');
      }

      String filePath;
      if (filename != null && filename.isNotEmpty) {
        // Serve specific file
        filePath = '${uploadsDir.path}/$filename';
        
        // Security check - only allow .wav, .m4a, .aac files
        final allowedExtensions = ['.wav', '.m4a', '.aac', '.mp3', '.ogg'];
        final hasAllowedExtension = allowedExtensions.any((ext) => filename.toLowerCase().endsWith(ext));
        
        if (!hasAllowedExtension) {
          return Response.forbidden('File type not allowed');
        }
      } else {
        // List available voice files or serve default
        return Response.ok(
          'Voice files endpoint. Use /voice/<filename> to access specific files.',
          headers: {'Content-Type': 'text/plain'},
        );
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return Response.notFound('Voice file not found: $filename');
      }

      // Determine content type
      String contentType = 'audio/mpeg'; // default
      final extension = filename?.toLowerCase().split('.').last;
      if (extension != null) {
        switch (extension) {
          case 'wav':
            contentType = 'audio/wav';
            break;
          case 'm4a':
          case 'aac':
            contentType = 'audio/aac';
            break;
          case 'mp3':
            contentType = 'audio/mpeg';
            break;
          case 'ogg':
            contentType = 'audio/ogg';
            break;
        }
      }

      final fileBytes = await file.readAsBytes();
      
      return Response.ok(
        fileBytes,
        headers: {
          'Content-Type': contentType,
          'Content-Length': fileBytes.length.toString(),
          'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
          'Accept-Ranges': 'bytes', // Support range requests for audio streaming
        },
      );
    } catch (e) {
      print('Error serving voice file: $e');
      return Response.internalServerError(
        body: {'success': false, 'message': 'Error serving voice file: $e'},
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
