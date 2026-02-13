import 'dart:io';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';

/// Enhanced media routes with proper audio streaming support
class EnhancedMediaRoutes {
  late final Router router;

  EnhancedMediaRoutes() {
    router = Router()
      ..get('/<storedFilename|.*>', _serveMedia);
  }

  /// Serve media files with enhanced headers and format support
  Future<Response> _serveMedia(Request request, String storedFilename) async {
    try {
      print('🎵 Media request for: $storedFilename');
      if (storedFilename.isEmpty) return Response.notFound('File not found');

      // Lookup file metadata with enhanced queries
      final conn = DBConnection.getConnection();
      var res = await conn.execute('''
        SELECT file_path, mime_type, stored_filename, file_size 
        FROM file_uploads 
        WHERE stored_filename = :storedFilename 
        OR id = :id
        LIMIT 1
      ''', {
        'storedFilename': storedFilename,
        'id': int.tryParse(storedFilename.split('.').first) ?? -1,
      });

      print('📊 Database query returned: ${res.rows.length} rows');

      if (res.rows.isEmpty) {
        // Try alternative lookups
        res = await conn.execute('''
          SELECT file_path, mime_type, stored_filename 
          FROM file_uploads 
          WHERE file_path LIKE :pathLike 
          OR stored_filename LIKE :filenameLike
          LIMIT 1
        ''', {
          'pathLike': '%$storedFilename%',
          'filenameLike': '%$storedFilename%',
        });
        print('🔄 Alternative query returned: ${res.rows.length} rows');
      }

      if (res.rows.isEmpty) {
        return Response.notFound('File not found in database');
      }

      final row = res.rows.first;
      final String? filePath = row.colByName('file_path');
      final String? mimeTypeDb = row.colByName('mime_type');
      final String? storedFilenameDb = row.colByName('stored_filename');

      if (filePath == null) {
        return Response.notFound('File path not found');
      }

      // Resolve actual file path
      var file = File(filePath!);
      if (!await file.exists()) {
        // Try with stored filename
        final parent = File(filePath!).parent;
        final tryPath = '${parent.path}/${storedFilenameDb ?? storedFilename}';
        final tryFile = File(tryPath);
        if (await tryFile.exists()) {
          file = tryFile;
        } else {
          return Response.notFound('File not found on disk');
        }
      }

      final int fileLength = await file.length();
      final String resolvedPath = file.path;

      // Enhanced MIME type detection and correction
      String mimeType = mimeTypeDb ?? lookupMimeType(resolvedPath) ?? 'application/octet-stream';
      
      // Fix common MIME type issues
      if (mimeType == 'application/octet-stream') {
        final extension = filePath!.toLowerCase().split('.').last;
        mimeType = _getCorrectMimeType(extension);
        print('🔧 Corrected MIME type: $extension → $mimeType');
      }

      // Enhanced headers for cross-platform audio support
      final Map<String, String> headers = {
        // Basic headers
        'Content-Type': mimeType,
        'Content-Length': fileLength.toString(),
        'Accept-Ranges': 'bytes',
        'Cache-Control': 'public, max-age=31536000',
        
        // Enhanced CORS headers
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS, POST',
        'Access-Control-Allow-Headers': 'Range, Content-Type, Accept, Authorization, Content-Length',
        'Access-Control-Expose-Headers': 'Content-Range, Accept-Ranges, Content-Length, Content-Type',
        'Access-Control-Allow-Credentials': 'true',
        'Access-Control-Max-Age': '86400',
        
        // Audio-specific headers
        'Content-Disposition': 'inline; filename="${storedFilenameDb ?? storedFilename}"',
        'X-Content-Type-Options': 'nosniff',
        
        // Security headers
        'X-Frame-Options': 'SAMEORIGIN',
        'X-XSS-Protection': '1; mode=block',
        'Referrer-Policy': 'strict-origin-when-cross-origin',
      };

      // Handle range requests for streaming
      final rangeHeader = request.headers['range'];
      if (rangeHeader != null && mimeType.startsWith('audio/')) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          final start = int.parse(match.group(1)!);
          final end = match.group(2)?.isEmpty ?? true 
            ? fileLength - 1 
            : int.parse(match.group(2)!);
          
          final clampedEnd = end.clamp(0, fileLength - 1);
          if (start > clampedEnd) {
            return Response(416, headers: headers);
          }

          final stream = file.openRead(start, clampedEnd + 1);
          final rangeHeaders = Map<String, String>.from(headers);
          rangeHeaders.addAll({
            'Content-Range': 'bytes $start-$clampedEnd/$fileLength',
            'Content-Length': '${clampedEnd - start + 1}',
          });
          
          print('📡 Serving range: $start-$clampedEnd/$fileLength');
          return Response(206, body: stream, headers: rangeHeaders);
        }
      }

      // Full content response
      print('📤 Serving full file: $fileLength bytes');
      return Response.ok(file.openRead(), headers: headers);

    } catch (e, st) {
      print('❌ Error serving media $storedFilename: $e');
      print('📍 Stack trace: $st');
      return Response.internalServerError(body: 'Internal server error: $e');
    }
  }

  /// Get correct MIME type for common audio formats
  String _getCorrectMimeType(String extension) {
    switch (extension) {
      case 'aac':
        return 'audio/aac';
      case 'm4a':
      case 'mp4':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'webm':
        return 'audio/webm';
      case 'flac':
        return 'audio/flac';
      default:
        return 'application/octet-stream';
    }
  }
}
