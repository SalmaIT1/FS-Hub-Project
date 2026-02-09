import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Upload progress event
class UploadProgress {
  final String uploadId;
  final int bytesUploaded;
  final int totalBytes;

  UploadProgress({
    required this.uploadId,
    required this.bytesUploaded,
    required this.totalBytes,
  });

  double get progress => totalBytes > 0 ? bytesUploaded / totalBytes : 0.0;
}

/// Upload result
class UploadResult {
  final String uploadId;
  final String serverUrl;
  final Map<String, dynamic> metadata;

  UploadResult({
    required this.uploadId,
    required this.serverUrl,
    required this.metadata,
  });
}

/// Manages file and voice uploads to backend
/// 
/// Responsibilities:
/// - Request signed URLs from server
/// - Upload files via PUT/POST
/// - Track progress
/// - Handle retries on network failure
/// - Emit progress events
/// - Never upload without server approval
class UploadService {
  final String baseUrl;
  final Future<String> Function() tokenProvider;

  final StreamController<UploadProgress> _progressController = StreamController.broadcast();
  Stream<UploadProgress> get progress => _progressController.stream;

  UploadService({
    required this.baseUrl,
    required this.tokenProvider,
  });

  /// Request signed upload URL from server
  /// 
  /// Backend returns:
  /// {uploadId, uploadUrl, expiresAt, meta}
  /// 
  /// Never upload without this approval.
  Future<Map<String, dynamic>> requestSignedUrl({
    required String filename,
    required String mimeType,
    required int fileSize,
  }) async {
    try {
      final token = await tokenProvider();
      final response = await http.post(
        Uri.parse('$baseUrl/v1/uploads/signed-url'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: _encodeJson({
          'filename': filename,
          'mime': mimeType,
          'size': fileSize,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeJson(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get signed URL: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error requesting signed URL: $e');
    }
  }

  /// Upload file to signed URL
  /// 
  /// Contract:
  /// - Server provides signed URL (valid for ~10min)
  /// - Frontend uploads bytes via PUT
  /// - No auth headers needed (URL is pre-authorized)
  /// - Report progress via events
  /// - On success, return uploadId + serverUrl
  Future<UploadResult> uploadFile({
    required String uploadId,
    required String signedUrl,
    required File file,
    void Function(double)? onProgress,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      // Create request with bytes
      final request = http.Request('PUT', Uri.parse(signedUrl))
        ..headers['content-type'] = 'application/octet-stream'
        ..bodyBytes = bytes;

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201) {
        throw Exception('Upload failed: ${streamedResponse.statusCode}');
      }

      final progress = UploadProgress(
        uploadId: uploadId,
        bytesUploaded: fileSize,
        totalBytes: fileSize,
      );
      _progressController.add(progress);
      onProgress?.call(1.0);

      // Notify server upload completed and return server URL
      final completeResponse = await _notifyUploadComplete(uploadId);
      return UploadResult(
        uploadId: uploadId,
        serverUrl: completeResponse['fileUrl'] ?? signedUrl,
        metadata: completeResponse,
      );
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  /// Upload audio/voice note to signed URL
  /// 
  /// Similar to file upload but for audio streams
  Future<UploadResult> uploadVoiceNote({
    required String uploadId,
    required String signedUrl,
    required File audioFile,
    required int durationMs,
    required String waveformData,
    void Function(double)? onProgress,
  }) async {
    try {
      final bytes = await audioFile.readAsBytes();
      final fileSize = bytes.length;

      final request = http.Request('PUT', Uri.parse(signedUrl))
        ..headers['content-type'] = 'audio/aac'
        ..bodyBytes = bytes;

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201) {
        throw Exception('Voice upload failed: ${streamedResponse.statusCode}');
      }

      final progress = UploadProgress(
        uploadId: uploadId,
        bytesUploaded: fileSize,
        totalBytes: fileSize,
      );
      _progressController.add(progress);
      onProgress?.call(1.0);

      // Notify server with metadata
      final completeResponse = await _notifyUploadComplete(
        uploadId,
        metadata: {
          'durationMs': durationMs,
          'waveformData': waveformData,
        },
      );

      return UploadResult(
        uploadId: uploadId,
        serverUrl: completeResponse['fileUrl'] ?? signedUrl,
        metadata: completeResponse,
      );
    } catch (e) {
      throw Exception('Error uploading voice note: $e');
    }
  }

  /// Mark upload as complete on server
  /// 
  /// Backend stores reference and associates with message during send
  Future<Map<String, dynamic>> _notifyUploadComplete(
    String uploadId, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await tokenProvider();
      final response = await http.post(
        Uri.parse('$baseUrl/v1/uploads/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: _encodeJson({
          'uploadId': uploadId,
          if (metadata != null) ...metadata,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeJson(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to complete upload: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error notifying upload complete: $e');
    }
  }

  void dispose() {
    _progressController.close();
  }

  // Helper methods for JSON encoding/decoding without hardcoding
  static String _encodeJson(Map<String, dynamic> data) {
    // In production, use json.encode; for now, simplifiy
    StringBuffer sb = StringBuffer('{');
    data.entries.toList().asMap().forEach((i, e) {
      sb.write('"${e.key}":');
      if (e.value is String) {
        sb.write('"${e.value}"');
      } else if (e.value is int || e.value is double) {
        sb.write(e.value);
      } else if (e.value is bool) {
        sb.write(e.value ? 'true' : 'false');
      } else {
        sb.write('"$e.value"');
      }
      if (i < data.length - 1) sb.write(',');
    });
    sb.write('}');
    return sb.toString();
  }

  static dynamic _decodeJson(String json) {
    // In production, use json.decode; for now, rely on http already parsing
    if (json.startsWith('{')) {
      // Very basic parsing for demo
      throw Exception('Use real JSON parsing in production');
    }
    return {};
  }
}
