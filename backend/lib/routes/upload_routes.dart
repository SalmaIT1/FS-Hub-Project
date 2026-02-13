import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/auth_service.dart';
import '../database/db_connection.dart';

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

  /// PUT upload to signed URL (pre-signed, no auth required)
  /// PUT /v1/uploads/<uploadId>/put
  Future<Response> _putUpload(Request request, String uploadId) async {
    try {
      // Read raw body bytes
      final bodyBytes = await request.read().expand((b) => b).toList();

      // Ensure upload directory exists
      final uploadDir = Directory('uploads');
      if (!await uploadDir.exists()) await uploadDir.create(recursive: true);

      // Lookup existing record to determine extension / stored filename
      final conn = DBConnection.getConnection();
      final query = 'SELECT stored_filename, mime_type FROM file_uploads WHERE id = :uploadId';
      final result = await conn.execute(query, {'uploadId': uploadId});
      if (result.rows.isEmpty) {
        return Response(
          404,
          body: jsonEncode({'success': false, 'message': 'Upload record not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = result.rows.first;
      String? storedFilename = row.colByName('stored_filename');
      final mimeType = row.colByName('mime_type') as String?;

      // Determine extension
      String extension = 'bin';
      if (storedFilename != null && storedFilename.contains('.')) {
        extension = storedFilename.split('.').last;
      } else if (mimeType != null && mimeType.contains('/')) {
        extension = mimeType.split('/').last;
      }

      final actualStoredFilename = '$uploadId.$extension';
      final filePath = '${uploadDir.path}/$actualStoredFilename';

      // Write file bytes
      final file = File(filePath);
      await file.writeAsBytes(bodyBytes);
      print('[DEBUG] _putUpload bodyBytes.length: ${bodyBytes.length}');

      // Update DB record to point to the actual file
      await conn.execute(
        'UPDATE file_uploads SET stored_filename = :stored_filename, file_path = :file_path, file_size = :file_size WHERE id = :id',
        {
          'stored_filename': actualStoredFilename,
          'file_path': filePath,
          'file_size': bodyBytes.length,
          'id': uploadId,
        },
      );

      return Response.ok(jsonEncode({'success': true, 'upload_id': uploadId}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('Error handling signed PUT upload: $e');
      return Response(500, body: jsonEncode({'success': false, 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  /// Main upload endpoint - handles multipart form data
  /// POST /v1/uploads
  /// multipart/form-data
  /// Returns: {upload_id, original_filename, stored_filename, file_path, file_size, mime_type, thumbnail_path?}
  Future<Response> _uploadFile(Request request) async {
    try {
      // Verify authentication
      final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Authorization required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.split(' ').last;
      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final uploadedBy = payload['userId'];
      
      // Parse multipart request
      final boundary = request.headers['content-type']?.split('boundary=')[1];
      if (boundary == null) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'Invalid multipart request'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Read the entire request body
      final bodyBytes = await request.read().expand((bytes) => bytes).toList();
      final body = String.fromCharCodes(bodyBytes);

      // Parse multipart data (simplified - in production use proper multipart parser)
      final parts = body.split('--$boundary');
      String? filename;
      String? mimeType;
      List<int>? fileBytes;

      for (final part in parts) {
        if (part.contains('Content-Disposition: form-data')) {
          final lines = part.split('\r\n');
          for (final line in lines) {
            if (line.contains('filename=')) {
              filename = line.split('filename="')[1].split('"')[0];
            }
            if (line.contains('Content-Type:')) {
              mimeType = line.split('Content-Type: ')[1].trim();
            }
          }
          
          // Extract file bytes (everything after the headers)
          final headerEnd = part.indexOf('\r\n\r\n');
          if (headerEnd != -1) {
            final fileContent = part.substring(headerEnd + 4);
            fileBytes = fileContent.codeUnits;
          }
        }
      }

      if (filename == null || fileBytes == null) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'No file found in request'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Generate upload ID and stored filename
      // Let the database auto-generate the numeric ID
      final tempUploadId = 'pending';
      final fileExtension = filename.split('.').last.toLowerCase();
      final storedFilename = '${tempUploadId}.$fileExtension';
      
      // Create upload directory if it doesn't exist
      final uploadDir = Directory('uploads');
      if (!await uploadDir.exists()) {
        await uploadDir.create(recursive: true);
      }

      // Save file to disk with temp name
      final filePath = '${uploadDir.path}/$storedFilename';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // Generate thumbnail for images
      String? thumbnailPath;
      if (mimeType?.startsWith('image/') == true) {
        thumbnailPath = await _generateThumbnail(filePath, tempUploadId);
      }

      // Insert into database
      final conn = DBConnection.getConnection();
      final insertQuery = '''
        INSERT INTO file_uploads (
          original_filename, stored_filename, file_path, file_size, 
          mime_type, uploaded_by, is_public, download_count, created_at, expires_at
        ) VALUES (
          :originalFilename, :storedFilename, :filePath, :file_size,
          :mimeType, :uploadedBy, :isPublic, :downloadCount, :createdAt, :expiresAt
        )
      ''';

      final result = await conn.execute(insertQuery, {
        'originalFilename': filename,
        'storedFilename': storedFilename,
        'filePath': filePath,
        'file_size': fileBytes.length,
        'mimeType': mimeType ?? 'application/octet-stream',
        'uploadedBy': uploadedBy,
        'isPublic': 0,
        'downloadCount': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      
      // Get the auto-generated ID
      String uploadId = '0';
      try {
        final lastInsertId = result.lastInsertID;
        uploadId = lastInsertId.toString();
      } catch (e) {
        print('Warning: Could not get lastInsertID: $e');
      }
      
      // Update the stored_filename and file_path with the actual upload ID
      try {
        final actualStoredFilename = '$uploadId.$fileExtension';
        final actualFilePath = '${uploadDir.path}/$actualStoredFilename';
        
        // Rename the file
        await file.rename(actualFilePath);
        
        await conn.execute(
          'UPDATE file_uploads SET stored_filename = :stored_filename, file_path = :file_path WHERE id = :id',
          {'stored_filename': actualStoredFilename, 'file_path': actualFilePath, 'id': uploadId},
        );
      } catch (e) {
        print('Warning: Could not update file path: $e');
      }

      final response = {
        'success': true,
        'upload_id': uploadId,
        'original_filename': filename,
        'stored_filename': storedFilename,
        'file_path': filePath,
        'file_size': fileBytes.length,
        'mime_type': mimeType ?? 'application/octet-stream',
        if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'},
      );

    } catch (e) {
      print('Error uploading file: $e');
      return Response(
          500,
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
    }
  }

  /// Get signed URL for upload (alternative to direct multipart)
  /// POST /v1/uploads/signed-url
  /// Body: {filename, mime, size}
  /// Returns: {upload_id, upload_url, expires_at}
  Future<Response> _getSignedUrl(Request request) async {
    try {
      final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Authorization required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.split(' ').last;
      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      final userId = payload['userId'] ?? payload['sub'];
      if (userId == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Token missing userId'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);

      final filename = data['filename'];
      final mimeType = data['mime'];
      final fileSizeRaw = data['size'];
      print('[DEBUG] fileSizeRaw type: ${fileSizeRaw?.runtimeType}, value: $fileSizeRaw');
      final fileSize = fileSizeRaw is int ? fileSizeRaw : int.tryParse(fileSizeRaw?.toString() ?? '0') ?? 0;
      print('[DEBUG] parsed fileSize: $fileSize');

      if (filename == null || mimeType == null || fileSizeRaw == null || fileSize <= 0) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'filename, mime, and size are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Generate upload ID and signed URL
      // Note: ID will be auto-generated by the database
      final tempUploadId = 'pending';  // Temporary placeholder
      final uploadUrl = 'http://localhost:8080/v1/uploads/{uploadId}/put';
      final expiresAt = DateTime.now().add(const Duration(minutes: 10));

      // Store upload metadata in database (pending state)
      final conn = DBConnection.getConnection();
      try {
        // Extract file extension safely
        final parts = filename.toString().split('.');
        final extension = parts.length > 1 ? parts.last : 'bin';
        
        final insertQuery = '''
          INSERT INTO file_uploads (
            original_filename, stored_filename, file_path, file_size,
            mime_type, uploaded_by, is_public, download_count, created_at, expires_at
          ) VALUES (
            :originalFilename, :storedFilename, :filePath, :file_size,
            :mimeType, :uploadedBy, :isPublic, :downloadCount, :createdAt, :expiresAt
          )
        ''';

        final result = await conn.execute(insertQuery, {
          'originalFilename': filename,
          'storedFilename': '$tempUploadId.$extension',
          'filePath': 'uploads/$tempUploadId',
          'file_size': fileSize,
          'mimeType': mimeType,
          'uploadedBy': userId,
          'isPublic': 0,
          'downloadCount': 0,
          'createdAt': DateTime.now().toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
        });
        print('[DEBUG] INSERT file_size: $fileSize');
        
        // Get the auto-generated ID from the database
        String uploadId = '0';
        try {
          // Try to get lastInsertID if available
          final lastInsertId = result.lastInsertID;
          uploadId = lastInsertId.toString();
        } catch (e) {
          // Fallback: query for the most recent upload ID
          print('Could not get lastInsertID: $e');
          dynamic idResult = await conn.execute(
            'SELECT id FROM file_uploads WHERE uploaded_by = :uploaded_by ORDER BY created_at DESC LIMIT 1',
            {'uploaded_by': userId}
          );
          if (idResult.isNotEmpty) {
            uploadId = idResult[0]['id'].toString();
          }
        }
        
        // Update the stored_filename and file_path with the actual upload ID
        try {
          await conn.execute(
            'UPDATE file_uploads SET stored_filename = :stored_filename, file_path = :file_path WHERE id = :id',
            {'stored_filename': '$uploadId.$extension', 'file_path': 'uploads/$uploadId.$extension', 'id': uploadId},
          );
        } catch (e) {
          print('Warning: Could not update stored filename: $e');
        }
        
        final actualUploadUrl = uploadUrl.replaceFirst('{uploadId}', uploadId);

        final response = {
          'success': true,
          'upload_id': uploadId,
          'upload_url': actualUploadUrl,
          'expires_at': expiresAt.toIso8601String(),
        };

        return Response.ok(
          jsonEncode(response),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (dbError) {
        print('Database error in _getSignedUrl: $dbError');
        rethrow;
      }

    } catch (e) {
      print('Error getting signed URL: $e');
      return Response(
          500,
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
    }
  }

  /// Complete upload after file is uploaded to signed URL
  /// POST /v1/uploads/complete
  /// Body: {upload_id, metadata?}
  Future<Response> _completeUpload(Request request) async {
    try {
      final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Authorization required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.split(' ').last;
      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);

      final uploadId = data['upload_id'];
      final metadata = data['metadata'];

      if (uploadId == null) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'upload_id is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Update upload record as completed
      final conn = DBConnection.getConnection();
      final updateQuery = '''
        UPDATE file_uploads 
        SET file_path = :filePath, created_at = :createdAt
        WHERE id = :uploadId
      ''';

      await conn.execute(updateQuery, {
        'uploadId': uploadId,
        'filePath': 'uploads/$uploadId',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final response = {
        'success': true,
        'upload_id': uploadId,
        'file_url': 'http://localhost:8080/uploads/$uploadId',
        if (metadata != null) 'metadata': metadata,
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'},
      );

    } catch (e) {
      print('Error completing upload: $e');
      return Response(
          500,
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
    }
  }

  /// Get upload status
  /// GET /v1/uploads/<uploadId>
  Future<Response> _getUploadStatus(Request request, String uploadId) async {
    try {
      final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Authorization required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.split(' ').last;
      final payload = AuthService.verifyToken(token);
      if (payload == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = DBConnection.getConnection();
      final query = '''
        SELECT id, original_filename, stored_filename, file_path, file_size,
               mime_type, uploaded_by, is_public, download_count, created_at, expires_at
        FROM file_uploads
        WHERE id = :uploadId
      ''';

      final result = await conn.execute(query, {'uploadId': uploadId});

      if (result.rows.isEmpty) {
        return Response(
          404,
          body: jsonEncode({'success': false, 'message': 'Upload not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = result.rows.first;
      final uploadData = {
        'success': true,
        'upload_id': row.colByName('id'),
        'original_filename': row.colByName('original_filename'),
        'stored_filename': row.colByName('stored_filename'),
        'file_path': row.colByName('file_path'),
        'file_size': row.colByName('file_size'),
        'mime_type': row.colByName('mime_type'),
        'uploaded_by': row.colByName('uploaded_by'),
        'is_public': row.colByName('is_public') == 1,
        'download_count': row.colByName('download_count'),
        'created_at': row.colByName('created_at'),
        'expires_at': row.colByName('expires_at'),
      };

      return Response.ok(
        jsonEncode(uploadData),
        headers: {'Content-Type': 'application/json'},
      );

    } catch (e) {
      print('Error getting upload status: $e');
      return Response(
          500,
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
    }
  }

  /// Generate thumbnail for images (simplified implementation)
  Future<String?> _generateThumbnail(String imagePath, String uploadId) async {
    try {
      // In a real implementation, you would use image processing library
      // For now, just return the same path as placeholder
      final thumbnailDir = Directory('uploads/thumbnails');
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      final thumbnailPath = '${thumbnailDir.path}/${uploadId}_thumb.jpg';
      final thumbnailFile = File(thumbnailPath);
      
      // Copy original as thumbnail (in real implementation, resize)
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
}
