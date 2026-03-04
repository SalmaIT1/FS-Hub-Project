import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/media_service.dart';

class MediaRoutes {
  late final Router router;

  MediaRoutes() {
    router = Router()
      ..get('/<storedFilename|.*>', _serveMedia);
  }

  Future<Response> _serveMedia(Request request, String storedFilename) async {
    try {
      if (storedFilename.isEmpty) return Response.notFound('File not found');

      final media = await MediaService.getMediaByStoredFilename(storedFilename);
      if (media == null) return Response.notFound('File not found in database');

      final file = await MediaService.resolveFile(media);
      if (file == null) return Response.notFound('File not found on disk');

      final int fileLength = await file.length();
      final String resolvedPath = file.path;

      String mimeType = media.mimeType;
      if (mimeType == 'application/octet-stream') {
        final extension = media.filePath.toLowerCase().split('.').last;
        mimeType = MediaService.getCorrectMimeType(extension);
      }

      final Map<String, String> headers = {
        'Content-Type': mimeType,
        'Content-Length': fileLength.toString(),
        'Accept-Ranges': 'bytes',
        'Cache-Control': 'public, max-age=31536000',
        'Access-Control-Allow-Origin': '*',
        'Content-Disposition': 'inline; filename="${media.storedFilename}"',
        'X-Content-Type-Options': 'nosniff',
      };

      final rangeHeader = request.headers['range'];
      if (rangeHeader != null && mimeType.startsWith('audio/')) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          final start = int.parse(match.group(1)!);
          final end = match.group(2)?.isEmpty ?? true ? fileLength - 1 : int.parse(match.group(2)!);
          final clampedEnd = end.clamp(0, fileLength - 1);
          if (start > clampedEnd) return Response(416, headers: headers);

          final stream = file.openRead(start, clampedEnd + 1);
          final rangeHeaders = Map<String, String>.from(headers);
          rangeHeaders.addAll({
            'Content-Range': 'bytes $start-$clampedEnd/$fileLength',
            'Content-Length': '${clampedEnd - start + 1}',
          });
          return Response(206, body: stream, headers: rangeHeaders);
        }
      }

      return Response.ok(file.openRead(), headers: headers);
    } catch (e, stack) {
      print('[MediaRoutes] 🔥 ERROR serving $storedFilename: $e\n$stack');
      return Response.internalServerError(body: 'Internal server error: $e');
    }
  }
}
