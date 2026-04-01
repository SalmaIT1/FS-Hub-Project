import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../domain/services/media_service.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/middleware/permission_middleware.dart';

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

      // H-6 FIX: Verify the user has access to this file if it is private.
      final bool hasAccess = await MediaService.canAccessMedia(
        media: media, 
        userId: request.authUserId, 
        isAdmin: request.isAdmin,
      );
      if (!hasAccess) return Response.forbidden('You do not have permission to access this file');

      final file = await MediaService.resolveFile(media);
      if (file == null) return Response.notFound('File not found on disk');

      final int fileLength = await file.length();
      final String resolvedPath = file.path;

      String mimeType = media.mimeType;
      if (mimeType == 'application/octet-stream') {
        final extension = media.filePath.toLowerCase().split('.').last;
        mimeType = MediaService.getCorrectMimeType(extension);
      }

      final bool isPublic = media.isPublic;

      final Map<String, String> headers = {
        'Content-Type': mimeType,
        'Content-Length': fileLength.toString(),
        'Accept-Ranges': 'bytes',
        // L-4 FIX: Private media should not be cached publicly for 1 year.
        'Cache-Control': isPublic ? 'public, max-age=86400' : 'private, no-store',
        // H-6 FIX: Wildcard CORS is only safe for truly public files.
        'Access-Control-Allow-Origin': isPublic ? '*' : 'null',
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
      return Response.internalServerError(body: 'Internal server error');
    }
  }
}
