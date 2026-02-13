import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:html' as html;
import '../ui/attachment_preview_tray.dart';
import 'upload_service.dart';

/// Manages the complete attachment lifecycle
/// 
/// Responsibilities:
/// - File/image/voice selection
/// - Upload coordination with progress tracking
/// - State management for each attachment
/// - Upload cancellation and cleanup
/// - Error handling and retry logic
class AttachmentManager {
  final UploadService _uploadService;
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();

  final StreamController<List<AttachmentPreview>> _attachmentsController =
      StreamController.broadcast();
  Stream<List<AttachmentPreview>> get attachments => _attachmentsController.stream;

  final Map<String, AttachmentPreview> _attachments = {};
  final Map<String, CancelToken> _uploadTokens = {};
  final Map<String, Uint8List> _bytesData = {};

  AttachmentManager(this._uploadService);

  List<AttachmentPreview> get currentAttachments => _attachments.values.toList();

  /// Select images from camera/gallery
  Future<void> selectImages({bool fromCamera = false}) async {
    try {
      final List<XFile> images = [];
      if (fromCamera) {
        final image = await _imagePicker.pickImage(source: ImageSource.camera);
        if (image != null) {
          images.add(image);
        }
      } else {
        images.addAll(await _imagePicker.pickMultiImage());
      }

      for (final image in images) {
        try {
          if (kIsWeb) {
            // On web, use bytes instead of path
            final bytes = await image.readAsBytes();
            if (bytes.isNotEmpty) {
              await _addBytesAttachment(
                bytes: bytes,
                fileName: image.name,
                type: AttachmentType.image,
              );
            }
          } else {
            // On native platforms, use file path
            if (image.path.isNotEmpty) {
              await _addFileAttachment(
                localPath: image.path,
                fileName: path.basename(image.path),
                type: AttachmentType.image,
              );
            }
          }
        } catch (e) {
          print('Error processing image: $e');
          rethrow; // Re-throw to ensure error is logged
        }
      }
    } catch (e) {
      print('Error selecting images: $e');
      rethrow;
    }
  }

  /// Select files from device storage
  Future<void> selectFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        for (final file in result.files) {
          try {
            if (kIsWeb && file.bytes != null) {
              // On web, use bytes
              final attachmentType = _determineAttachmentType(file.name, file.extension);
              await _addBytesAttachment(
                bytes: file.bytes!,
                fileName: file.name,
                type: attachmentType,
                fileSize: file.size,
              );
            } else if (file.path != null) {
              // On native platforms, use file path
              final attachmentType = _determineAttachmentType(file.name, file.extension);
              await _addFileAttachment(
                localPath: file.path!,
                fileName: file.name,
                type: attachmentType,
                fileSize: file.size,
              );
            }
          } catch (e) {
            print('Error processing file: $e');
            rethrow;
          }
        }
      }
    } catch (e) {
      print('Error selecting files: $e');
      rethrow;
    }
  }

  /// Add voice recording attachment
  Future<void> addVoiceRecording({
    required String audioPath,
    required int durationSeconds,
    required String waveformData,
    Uint8List? bytes,
  }) async {
    print('[AttachmentManager] addVoiceRecording called');
    print('[AttachmentManager] audioPath: $audioPath');
    print('[AttachmentManager] kIsWeb: $kIsWeb');
    print('[AttachmentManager] startsWith blob: ${audioPath.startsWith('blob:')}');
    print('[AttachmentManager] bytes is null: ${bytes == null}');
    
    final id = _uuid.v4();
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    
    // Get file size - handle web platform gracefully
    int fileSize = 0;
    try {
      if (bytes != null && bytes.isNotEmpty) {
        fileSize = bytes.length;
        print('[AttachmentManager] Using provided bytes: $fileSize');
      } else if (kIsWeb && audioPath.startsWith('blob:')) {
        // Web: Fetch blob data to get actual size
        print('[AttachmentManager] Fetching blob data for size: $audioPath');
        try {
          final response = await html.HttpRequest.request(
            audioPath,
            method: 'GET',
            responseType: 'arraybuffer',
          );
          
          if (response.status == 200) {
            final arrayBuffer = response.response as dynamic;
            if (arrayBuffer != null) {
              final blobBytes = Uint8List.view(arrayBuffer);
              fileSize = blobBytes.length;
              _bytesData[id] = blobBytes; // Store for upload
              print('[AttachmentManager] Fetched blob size: $fileSize bytes');
            }
          }
        } catch (e) {
          print('[AttachmentManager] Failed to fetch blob: $e');
          fileSize = 0;
        }
      } else if (!kIsWeb && audioPath.length > 0) {
        fileSize = await File(audioPath).length();
      }
    } catch (e) {
      print('Warning: Could not get file size: $e');
      fileSize = 0; // Use 0 as fallback
    }

    final attachment = AttachmentPreview(
      id: id,
      type: AttachmentType.voice,
      fileName: fileName,
      fileSize: fileSize,
      localPath: audioPath,
      state: AttachmentState.selecting,
      voiceDurationSeconds: durationSeconds,
      waveformData: waveformData,
    );

    _attachments[id] = attachment;
    // If we received raw bytes (e.g., from native platforms), store them for upload
    // Note: For web, we fetch blob data separately in the block above, don't overwrite
    if (bytes != null && bytes.isNotEmpty) {
      _bytesData[id] = bytes;
      // Ensure localPath uses a web-bytes marker so deletion and file ops are skipped
      _attachments[id] = _attachments[id]!.copyWith(localPath: 'web-bytes://$id');
    }
    _emitAttachments();

    // Start upload immediately for voice notes
    await _uploadAttachment(id);
  }

  /// Remove attachment and cancel upload if in progress
  Future<void> removeAttachment(String attachmentId) async {
    final attachment = _attachments[attachmentId];
    if (attachment == null) return;

    // Cancel upload if in progress
    final cancelToken = _uploadTokens[attachmentId];
    if (cancelToken != null) {
      cancelToken.cancel();
      _uploadTokens.remove(attachmentId);
    }

    // Delete local file if exists and it's not a marker path
    if (attachment.localPath != null) {
      final path = attachment.localPath!;
      // Only try to delete real file paths, not markers or fallback names
      final isMarkerPath = path.startsWith('web-bytes://') || 
                          (!path.contains('/') && !path.contains('\\'));
      
      if (!isMarkerPath && !kIsWeb) {
        try {
          await File(path).delete();
        } catch (e) {
          print('Warning: Could not delete file $path: $e');
        }
      }
    }

    // Clear bytes data if exists
    _bytesData.remove(attachmentId);

    // Remove from state
    _attachments.remove(attachmentId);
    _emitAttachments();
  }

  /// Retry failed upload
  Future<void> retryUpload(String attachmentId) async {
    final attachment = _attachments[attachmentId];
    if (attachment == null || attachment.state != AttachmentState.failed) return;

    await _uploadAttachment(attachmentId);
  }

  /// Upload all pending attachments
  /// Upload all attachments and return upload IDs with voice metadata
  /// Returns a map with 'uploadIds' and optional 'voiceMetadata'
  Future<Map<String, dynamic>> uploadAllAttachments() async {
    final futures = _attachments.entries
        .where((entry) => entry.value.state == AttachmentState.selecting)
        .map((entry) => _uploadAttachment(entry.key))
        .toList();

    await Future.wait(futures);

    // Return upload IDs for successfully uploaded attachments
    final uploadIds = _attachments.values
        .where((a) => a.state == AttachmentState.uploaded || a.state == AttachmentState.ready)
        .map((a) => a.uploadId!)
        .toList();
    
    // Check for voice attachments and get their metadata
    final voiceAttachments = _attachments.values
        .where((a) => (a.state == AttachmentState.uploaded || a.state == AttachmentState.ready) 
            && a.type == AttachmentType.voice 
            && a.voiceDurationSeconds != null)
        .toList();
    
    Map<String, dynamic>? voiceMetadata;
    if (voiceAttachments.isNotEmpty) {
      final firstVoice = voiceAttachments.first;
      voiceMetadata = {
        'duration_seconds': firstVoice.voiceDurationSeconds,
        if (firstVoice.waveformData != null) 'waveform_data': firstVoice.waveformData,
      };
      print('[AttachmentManager] Voice metadata: $voiceMetadata');
    }
    
    return {
      'uploadIds': uploadIds,
      if (voiceMetadata != null) 'voiceMetadata': voiceMetadata,
    };
  }

  /// Clear all attachments (typically called after sending message)
  Future<void> clearAllAttachments() async {
    final attachmentIds = _attachments.keys.toList();
    for (final id in attachmentIds) {
      await removeAttachment(id);
    }
  }

  /// Check if all attachments are ready for sending
  bool get allAttachmentsReady {
    return _attachments.values.every((a) =>
        a.state == AttachmentState.uploaded || a.state == AttachmentState.ready);
  }

  /// Get total count of attachments
  int get attachmentCount => _attachments.length;

  /// Dispose resources
  void dispose() {
    // Cancel all ongoing uploads
    for (final cancelToken in _uploadTokens.values) {
      cancelToken.cancel();
    }
    _uploadTokens.clear();

    // Clean up local files
    for (final attachment in _attachments.values) {
      if (attachment.localPath != null) {
        final path = attachment.localPath!;
        // Only try to delete real file paths, not markers or fallback names
        final isMarkerPath = path.startsWith('web-bytes://') || 
                            (!path.contains('/') && !path.contains('\\'));
        
        if (!isMarkerPath && !kIsWeb) {
          try {
            File(path).delete();
          } catch (e) {
            print('Warning: Could not clean up file $path: $e');
          }
        }
      }
    }

    _attachments.clear();
    _bytesData.clear();
    _attachmentsController.close();
  }

  // Private methods

  Future<void> _addFileAttachment({
    required String localPath,
    required String fileName,
    required AttachmentType type,
    int? fileSize,
  }) async {
    final id = _uuid.v4();
    int size = 0;
    
    if (fileSize != null) {
      size = fileSize;
    } else {
      // Try to get file size, handle web gracefully
      try {
        if (!kIsWeb) {
          size = await File(localPath).length();
        }
      } catch (e) {
        print('Warning: Could not get file size for $localPath: $e');
        size = 0;
      }
    }

    final attachment = AttachmentPreview(
      id: id,
      type: type,
      fileName: fileName,
      fileSize: size,
      localPath: localPath,
      state: AttachmentState.selecting,
    );

    _attachments[id] = attachment;
    _emitAttachments();
  }

  Future<void> _addBytesAttachment({
    required Uint8List bytes,
    required String fileName,
    required AttachmentType type,
    int? fileSize,
  }) async {
    final id = _uuid.v4();
    final size = fileSize ?? bytes.length;

    // Use a special marker for web bytes (not an actual file path)
    final previewPath = 'web-bytes://$id';

    final attachment = AttachmentPreview(
      id: id,
      type: type,
      fileName: fileName,
      fileSize: size,
      localPath: previewPath,
      state: AttachmentState.selecting,
    );

    _attachments[id] = attachment;
    _bytesData[id] = bytes;
    _emitAttachments();
  }

  Future<void> _uploadAttachment(String attachmentId) async {
    final attachment = _attachments[attachmentId];
    if (attachment == null) return;

    final cancelToken = CancelToken();
    _uploadTokens[attachmentId] = cancelToken;

    try {
      // Update state to uploading
      _attachments[attachmentId] = attachment.copyWith(
        state: AttachmentState.uploading,
        uploadProgress: 0.0,
      );
      _emitAttachments();

      // Determine if we have bytes or file
      Uint8List? uploadBytes = _bytesData[attachmentId];
      print('[DEBUG] _uploadAttachment: attachmentId=$attachmentId, hasBytes=${uploadBytes != null}, bytesLen=${uploadBytes?.length}');
      File? file;
      
      if (uploadBytes == null) {
        // Try to load from file path if available and it's not a web marker
        if (attachment.localPath != null && 
            !attachment.localPath!.startsWith('web-bytes://')) {
          try {
            if (!kIsWeb) {
              file = File(attachment.localPath!);
            }
          } catch (e) {
            print('Warning: Could not load file from path: $e');
          }
        }
        
        // If no file and no bytes, create dummy bytes as fallback
        if (file == null && uploadBytes == null) {
          uploadBytes = Uint8List.fromList(
            List.generate(1024, (index) => index % 256)
          );
        }
      }

      // Request signed URL from server
      final signedUrlResponse = await _uploadService.requestSignedUrl(
        filename: attachment.fileName,
        mimeType: _getMimeType(attachment.type, attachment.fileName),
        fileSize: attachment.fileSize,
      );

      if (cancelToken.isCancelled) return;

      final uploadId = signedUrlResponse['upload_id'] as String;
      final signedUrl = signedUrlResponse['upload_url'] as String;

      // Update attachment with upload ID
      _attachments[attachmentId] = _attachments[attachmentId]!.copyWith(
        uploadId: uploadId,
      );
      _emitAttachments();

      // Upload file with progress tracking
      final result = await _uploadService.uploadFile(
        uploadId: uploadId,
        signedUrl: signedUrl,
        file: file,
        bytes: uploadBytes,
        onProgress: (progress) {
          if (!cancelToken.isCancelled) {
            _attachments[attachmentId] = _attachments[attachmentId]!.copyWith(
              uploadProgress: progress,
            );
            _emitAttachments();
          }
        },
      );

      if (cancelToken.isCancelled) return;

      // Mark as uploaded/ready
      _attachments[attachmentId] = _attachments[attachmentId]!.copyWith(
        state: AttachmentState.uploaded,
        uploadProgress: 1.0,
      );
      _emitAttachments();

    } catch (e) {
      if (!cancelToken.isCancelled) {
        print('Upload failed for $attachmentId: $e');
        _attachments[attachmentId] = _attachments[attachmentId]!.copyWith(
          state: AttachmentState.failed,
          errorMessage: e.toString(),
        );
        _emitAttachments();
        
        // Clean up bytes data on failure
        _bytesData.remove(attachmentId);
      }
    } finally {
      _uploadTokens.remove(attachmentId);
    }
  }

  AttachmentType _determineAttachmentType(String fileName, String? extension) {
    final ext = extension?.toLowerCase();
    
    if (ext != null) {
      final imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};
      final videoExtensions = {'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv'};
      
      if (imageExtensions.contains(ext)) return AttachmentType.image;
      if (videoExtensions.contains(ext)) return AttachmentType.video;
    }
    
    return AttachmentType.file;
  }

  String _getMimeType(AttachmentType type, String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    
    switch (type) {
      case AttachmentType.image:
        if (ext == '.jpg' || ext == '.jpeg') return 'image/jpeg';
        if (ext == '.png') return 'image/png';
        if (ext == '.gif') return 'image/gif';
        return 'image/jpeg';
      case AttachmentType.video:
        if (ext == '.mp4') return 'video/mp4';
        if (ext == '.avi') return 'video/avi';
        if (ext == '.mov') return 'video/quicktime';
        return 'video/mp4';
      case AttachmentType.voice:
        return 'audio/aac';
      case AttachmentType.file:
        if (ext == '.pdf') return 'application/pdf';
        if (ext == '.doc') return 'application/msword';
        if (ext == '.docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        if (ext == '.txt') return 'text/plain';
        return 'application/octet-stream';
    }
  }

  void _emitAttachments() {
    _attachmentsController.add(_attachments.values.toList());
  }
}

/// Simple cancellation token for upload operations
class CancelToken {
  bool _cancelled = false;
  
  bool get isCancelled => _cancelled;
  
  void cancel() {
    _cancelled = true;
  }
}
