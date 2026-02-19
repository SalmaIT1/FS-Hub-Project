import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';

class MediaRoutes {
  late final Router router;

  MediaRoutes() {
    router = Router()
      ..get('/<storedFilename|.*>', _serveMedia);
  }

  /// Serve media files from disk using stored filename.
  /// Example: GET /media/12345.jpg
  Future<Response> _serveMedia(Request request, String storedFilename) async {
    try {
      print('Media request for: $storedFilename');
      if (storedFilename.isEmpty) return Response.notFound('Not found');

      // Lookup file meta in DB by stored_filename
      final conn = DBConnection.getConnection();
      var res = await conn.execute('''SELECT file_path, mime_type, stored_filename FROM file_uploads WHERE stored_filename = :storedFilename LIMIT 1''', {'storedFilename': storedFilename});
      print('Query by stored_filename returned: ${res.rows.length} rows');
      
      // If not found in file_uploads, try employee photos
      if (res.rows.isEmpty) {
        res = await conn.execute('''SELECT photo as file_path, 'image/jpeg' as mime_type, :storedFilename as stored_filename FROM employees WHERE photo LIKE :like LIMIT 1''', {'like': '%${storedFilename}', 'storedFilename': storedFilename});
        print('Query employee photos returned: ${res.rows.length} rows');
        
        // If still empty, try exact match on filename part
        if (res.rows.isEmpty) {
          final filenameWithoutExt = storedFilename.contains('.') ? storedFilename.split('.').first : storedFilename;
          res = await conn.execute('''SELECT photo as file_path, 'image/jpeg' as mime_type, :storedFilename as stored_filename FROM employees WHERE photo LIKE :like LIMIT 1''', {'like': '%${filenameWithoutExt}%', 'storedFilename': storedFilename});
          print('Query employee photos with filename part returned: ${res.rows.length} rows');
        }
      }
      // If not found by stored_filename, try other heuristics
      if (res.rows.isEmpty) {
        // If supplied value looks like an ID (numeric), try by id
        final idCandidate = int.tryParse(storedFilename.split('.').first);
        if (idCandidate != null) {
          res = await conn.execute('''SELECT file_path, mime_type, stored_filename FROM file_uploads WHERE id = :id LIMIT 1''', {'id': idCandidate});
          print('Query by id returned: ${res.rows.length} rows (idCandidate=$idCandidate)');
        }
      }

      if (res.rows.isEmpty) {
        // Try matching by file_path suffix (handles cases where stored filename ended up in file_path)
        res = await conn.execute('''SELECT file_path, mime_type, stored_filename FROM file_uploads WHERE file_path LIKE :like LIMIT 1''', {'like': '%/${storedFilename}'});
        print('Query by file_path with slash returned: ${res.rows.length} rows');
      }

      if (res.rows.isEmpty) {
        // Try matching without path separator (e.g. 'uploads/10.jpg' stored without leading slash)
        res = await conn.execute('''SELECT file_path, mime_type, stored_filename FROM file_uploads WHERE file_path LIKE :like LIMIT 1''', {'like': '%${storedFilename}'});
        print('Query by file_path without slash returned: ${res.rows.length} rows');
      }

      if (res.rows.isEmpty) {
        // Try matching with backslash (windows paths)
        res = await conn.execute('''SELECT file_path, mime_type, stored_filename FROM file_uploads WHERE file_path LIKE :like LIMIT 1''', {'like': '%\\${storedFilename}'});
      }

      if (res.rows.isEmpty) return Response.notFound('Not found');

      final row = res.rows.first;
      final String? filePath = row.colByName('file_path');
      final String? mimeTypeDb = row.colByName('mime_type');

      if (filePath == null) return Response.notFound('Not found');

      // Check if photo is stored as base64 data
      if (filePath.startsWith('data:image') || filePath.startsWith('iVBORw0K') || (filePath.length > 100 && !filePath.contains('/') && !filePath.contains('\\'))) {
        // This appears to be base64 image data
        try {
          String base64Data = filePath;
          if (filePath.startsWith('data:image')) {
            // Remove data URL prefix
            final commaIndex = filePath.indexOf(',');
            if (commaIndex != -1) {
              base64Data = filePath.substring(commaIndex + 1);
            }
          }
          
          final decodedBytes = const Base64Decoder().convert(base64Data);
          final String resolvedPath = storedFilename;
          final String mimeType = mimeTypeDb ?? lookupMimeType(resolvedPath) ?? 'image/jpeg';

          final headers = {
            'Content-Type': mimeType,
            'Cache-Control': 'public, max-age=31536000',
            'Access-Control-Allow-Origin': '*',
            'Content-Length': decodedBytes.length.toString(),
          };

          return Response.ok(decodedBytes, headers: headers);
        } catch (e) {
          print('Error serving base64 image: $e');
          return Response.notFound('Invalid image data');
        }
      }

      // Resolve on-disk path. DB `file_path` may be stored without extension
      // (e.g. 'uploads/10') while `stored_filename` contains '10.jpg'.
      final storedFilenameDb = row.colByName('stored_filename');
      var file = File(filePath);
      if (!await file.exists()) {
        if (storedFilenameDb != null) {
          final parent = file.parent.path;
          final tryPath = '$parent/${storedFilenameDb}';
          final tryFile = File(tryPath);
          if (await tryFile.exists()) {
            file = tryFile;
          } else {
            return Response.notFound('Not found');
          }
        } else {
          return Response.notFound('Not found');
        }
      }

      final int fileLength = await file.length();

      final String resolvedPath = file.path;
      final String mimeType = mimeTypeDb ?? lookupMimeType(resolvedPath) ?? 'application/octet-stream';

      // Enhanced headers for audio streaming
      final Map<String, String> baseHeaders = {
        'Content-Type': mimeType,
        'Accept-Ranges': 'bytes',
        'Cache-Control': 'public, max-age=31536000',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Range,Content-Type,Accept,Content-Range',
        'Access-Control-Expose-Headers': 'Content-Range,Accept-Ranges,Content-Length,Content-Type',
        'Access-Control-Allow-Credentials': 'true',
      };

      // Additional headers for audio files
      if (mimeType.startsWith('audio/')) {
        baseHeaders.addAll({
          'Content-Disposition': 'inline; filename="$storedFilename"',
          'X-Content-Type-Options': 'nosniff',
          'Accept-Ranges': 'bytes',
        });
      }

      // Range request support for audio/video
      final rangeHeader = request.headers['range'];
      if (rangeHeader != null && (mimeType.startsWith('audio/') || mimeType.startsWith('video/'))) {
        // Parse bytes=start-end
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          final start = int.parse(match.group(1)!);
          final end = match.group(2) != null && match.group(2)!.isNotEmpty ? int.parse(match.group(2)!) : fileLength - 1;
          final clampedEnd = end.clamp(0, fileLength - 1);
          if (start > clampedEnd) return Response(416);
          final stream = file.openRead(start, clampedEnd + 1);
          final rangeHeaders = Map<String, String>.from(baseHeaders);
          rangeHeaders.addAll({
            'Content-Length': '${clampedEnd - start + 1}',
            'Content-Range': 'bytes $start-$clampedEnd/$fileLength',
          });
          return Response(206, body: stream, headers: rangeHeaders);
        }
      }

      // Full content
      final stream = file.openRead();
      final isInline = mimeType.startsWith('image/') || mimeType.startsWith('audio/') || mimeType.startsWith('video/');
      final disposition = isInline ? 'inline' : 'attachment';

      final fullHeaders = Map<String, String>.from(baseHeaders);
      fullHeaders.addAll({
        'Content-Length': fileLength.toString(),
        'Content-Disposition': '$disposition; filename="$storedFilename"',
      });

      return Response.ok(stream, headers: fullHeaders);

    } catch (e, st) {
      print('Error serving media $storedFilename: $e\n$st');
      return Response.internalServerError(body: 'Internal server error');
    }
  }
}
