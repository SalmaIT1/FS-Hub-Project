import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/db_connection.dart';

/// Production-ready media routes with proper audio handling
class ProductionMediaRoutes {
  
  ProductionMediaRoutes();
  
  /// Get all routes
  Router get router {
    final router = Router();
    
    // Serve audio files with proper headers and range support
    router.get('/media/<filename>', _serveAudioFile);
    
    return router;
  }
  
  /// Serve audio file with production-ready streaming
  Future<Response> _serveAudioFile(Request request) async {
    final filename = request.params['filename'];
    
    if (filename == null || filename!.isEmpty) {
      return Response(400, body: 'Filename required');
    }
    
    try {
      // Look up audio file in database
      final conn = DBConnection.getConnection();
      final audioResult = await conn.execute('''
        SELECT file_path, mime_type, stored_filename, original_filename 
        FROM file_uploads 
        WHERE stored_filename = :filename OR original_filename = :filename
        LIMIT 1
      ''', {'filename': filename});
      
      if (audioResult.rows.isEmpty) {
        return Response(404, body: 'Audio file not found');
      }
      
      final row = audioResult.rows.first;
      final filePath = row.colByName('file_path');
      final mimeType = row.colByName('mime_type') ?? 'audio/aac';
      final storedFilename = row.colByName('stored_filename') ?? filename;
      
      if (filePath == null) {
        return Response(404, body: 'Audio file path not found');
      }
      
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        return Response(404, body: 'Audio file not found on disk');
      }
      
      final fileSize = await file.length();
      final fileStat = await file.stat();
      
      // Parse range header
      final rangeHeader = request.headers['range'];
      int start = 0;
      int end = fileSize - 1;
      int statusCode = 200;
      
      if (rangeHeader != null) {
        // Handle range requests for streaming
        if (rangeHeader.startsWith('bytes=')) {
          final parts = rangeHeader.substring(6).split('-');
          start = int.parse(parts[0]);
          if (parts.length > 1) {
            end = int.parse(parts[1]);
          }
          statusCode = 206; // Partial Content
        }
      }
      
      final contentLength = end - start + 1;
      
      // Open file and seek to position
      final randomAccessFile = await file.open();
      await randomAccessFile.setPosition(start);
      final data = await randomAccessFile.read(contentLength);
      await randomAccessFile.close();
      
      // Build production-ready headers
      final headers = <String, String>{
        // Content headers
        'Content-Type': mimeType,
        'Content-Length': contentLength.toString(),
        'Accept-Ranges': 'bytes',
        
        // Cache headers
        'Cache-Control': 'public, max-age=3600',
        'ETag': '"${fileStat.modified.millisecondsSinceEpoch}"',
        
        // CORS headers
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Range, Content-Type',
        'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges',
        
        // Security headers
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        
        // Audio-specific headers
        'Content-Disposition': 'inline; filename="$storedFilename"',
      };
      
      // Add range headers if partial content
      if (statusCode == 206) {
        headers['Content-Range'] = 'bytes $start-$end/$fileSize';
      }
      
      print('🎵 Serving audio: $storedFilename');
      print('📊 File size: $contentLength bytes');
      print('🎯 Range: $start-$end ($statusCode)');
      print('🎵 MIME type: $mimeType');
      
      return Response(
        statusCode,
        body: data,
        headers: headers,
      );
      
    } catch (e) {
      print('❌ Error serving audio file: $e');
      return Response(500, body: 'Internal server error');
    }
  }
  
  /// Handle OPTIONS requests for CORS
  Future<Response> _handleOptions(Request request) async {
    return Response.ok(
      null,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Range, Content-Type',
        'Access-Control-Max-Age': '86400',
      },
    );
  }
}
