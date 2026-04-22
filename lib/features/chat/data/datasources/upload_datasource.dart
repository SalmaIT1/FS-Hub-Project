import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class UploadDatasource {
  final String baseUrl;
  final Future<String> Function() tokenProvider;

  UploadDatasource({required this.baseUrl, required this.tokenProvider});

  Future<Map<String, dynamic>> requestSignedUrl({
    required String filename,
    required String mimeType,
    required int fileSize,
  }) async {
    final token = await tokenProvider();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/uploads/signed-url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'contentType': mimeType,
        'filename': filename,
        'fileSize': fileSize,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get signed URL: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> uploadFile({
    required String uploadId,
    required String signedUrl,
    File? file,
    List<int>? bytes,
    void Function(double)? onProgress,
  }) async {
    if (kIsWeb && bytes != null) {
      // For web, use bytes directly
      return await uploadBytes(
        signedUrl: signedUrl,
        bytes: bytes,
        contentType: 'application/octet-stream',
        onProgress: onProgress,
      ).then((url) => {'uploadId': uploadId, 'serverUrl': url});
    }

    if (file != null) {
      final fileBytes = await file.readAsBytes();
      return await uploadBytes(
        signedUrl: signedUrl,
        bytes: fileBytes,
        contentType: 'application/octet-stream',
        onProgress: onProgress,
      ).then((url) => {'uploadId': uploadId, 'serverUrl': url});
    }

    throw ArgumentError('Either file or bytes must be provided');
  }

  Future<String> uploadBytes({
    required String signedUrl,
    required List<int> bytes,
    required String contentType,
    void Function(double)? onProgress,
  }) async {
    final token = await tokenProvider();
    final request = http.Request('PUT', Uri.parse(signedUrl));
    request.headers['Content-Type'] = contentType;
    request.headers['Authorization'] = 'Bearer $token';
    request.bodyBytes = bytes;

    final response = await http.Client().send(request);
    
    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode}');
    }

    return signedUrl.split('?').first;
  }

  Future<Map<String, dynamic>> uploadVoiceNote({
    required String uploadId,
    required String signedUrl,
    required File audioFile,
    required int durationMs,
    required String waveformData,
    void Function(double)? onProgress,
  }) async {
    final bytes = await audioFile.readAsBytes();
    
    await uploadBytes(
      signedUrl: signedUrl,
      bytes: bytes,
      contentType: 'audio/aac',
      onProgress: onProgress,
    );

    // Notify backend about the upload completion
    final token = await tokenProvider();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/uploads/$uploadId/complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: '{"durationMs": $durationMs, "waveformData": "$waveformData"}',
    );

    if (response.statusCode == 200) {
      return {
        'uploadId': uploadId,
        'serverUrl': signedUrl.split('?').first,
      };
    }
    
    return {
      'uploadId': uploadId,
      'serverUrl': signedUrl.split('?').first,
    };
  }

  Future<Map<String, dynamic>> getUploadStatus(String uploadId) async {
    final token = await tokenProvider();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/uploads/$uploadId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {} as Map<String, dynamic>;
    }
    throw Exception('Failed to get upload status: ${response.statusCode}');
  }
}
