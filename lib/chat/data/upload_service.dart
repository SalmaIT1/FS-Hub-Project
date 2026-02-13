import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:html' as html;

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
      
      if (token.isEmpty) {
        throw Exception('No authentication token available');
      }
      
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
        final result = _decodeJson(response.body) as Map<String, dynamic>;
        return result;
      } else {
        final errorBody = response.body.isNotEmpty ? response.body : 'No response body';
        print('Signed URL request failed: ${response.statusCode} - $errorBody');
        throw Exception('Failed to get signed URL (${response.statusCode}): $errorBody');
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
    required File? file,
    Uint8List? bytes,
    void Function(double)? onProgress,
  }) async {
    try {
      print('[DEBUG] uploadFile called: uploadId=$uploadId, hasBytes=${bytes != null}, bytesLen=${bytes?.length}, hasFile=${file != null}');
      final uploadBytes = bytes ?? await file!.readAsBytes();
      final fileSize = uploadBytes.length;
      print('[DEBUG] uploadFile: final uploadBytes length = ${uploadBytes.length}');

      // Create request with bytes
      final request = http.Request('PUT', Uri.parse(signedUrl))
        ..headers['content-type'] = 'application/octet-stream'
        ..bodyBytes = uploadBytes;

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
      print('[UPLOAD] uploadVoiceNote called: uploadId=$uploadId, audioFile.path=${audioFile.path}');
      print('[UPLOAD] DEBUG: kIsWeb = $kIsWeb');
      print('[UPLOAD] DEBUG: isBlob = ${audioFile.path.startsWith('blob:')}');
      
      Uint8List bytes;
      
      if (kIsWeb && audioFile.path.startsWith('blob:')) {
        // Web: Fetch blob data using dart:html
        print('[UPLOAD] Web blob detected, fetching data...');
        try {
          final response = await html.HttpRequest.request(
            audioFile.path,
            method: 'GET',
            responseType: 'arraybuffer',
          );
          
          if (response.status == 200) {
            final arrayBuffer = response.response as dynamic;
            if (arrayBuffer != null) {
              bytes = Uint8List.view(arrayBuffer);
              print('[UPLOAD] Fetched ${bytes.length} bytes from blob');
            } else {
              throw Exception('ArrayBuffer is null');
            }
          } else {
            throw Exception('Failed to fetch blob data: ${response.status}');
          }
        } catch (e) {
          print('[UPLOAD] Blob fetch error: $e');
          throw Exception('Failed to fetch blob data: $e');
        }
      } else {
        // Desktop/Mobile: Read file bytes
        bytes = await audioFile.readAsBytes();
        print('[UPLOAD] Read ${bytes.length} bytes from file');
      }
      
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
          'upload_id': uploadId,
          if (metadata != null) 'metadata': metadata,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = _decodeJson(response.body) as Map<String, dynamic>;
        return decoded;
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
    return json.encode(data);
  }

  static dynamic _decodeJson(String jsonStr) {
    return json.decode(jsonStr);
  }
}
