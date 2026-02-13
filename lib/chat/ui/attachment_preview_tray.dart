import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/upload_service.dart';
import '../state/chat_controller.dart';

/// Attachment types supported by the system
enum AttachmentType {
  image,
  video,
  file,
  voice,
}

/// Attachment state tracking
enum AttachmentState {
  selecting,
  uploading,
  uploaded,
  failed,
  ready,
}

/// Attachment preview model
class AttachmentPreview {
  final String id;
  final AttachmentType type;
  final String fileName;
  final int fileSize;
  final String? localPath;
  final String? thumbnailPath;
  final String? uploadId;
  final AttachmentState state;
  final double uploadProgress;
  final String? errorMessage;
  final int? voiceDurationSeconds;
  final String? waveformData;

  const AttachmentPreview({
    required this.id,
    required this.type,
    required this.fileName,
    required this.fileSize,
    this.localPath,
    this.thumbnailPath,
    this.uploadId,
    required this.state,
    this.uploadProgress = 0.0,
    this.errorMessage,
    this.voiceDurationSeconds,
    this.waveformData,
  });

  AttachmentPreview copyWith({
    String? id,
    AttachmentType? type,
    String? fileName,
    int? fileSize,
    String? localPath,
    String? thumbnailPath,
    String? uploadId,
    AttachmentState? state,
    double? uploadProgress,
    String? errorMessage,
    int? voiceDurationSeconds,
    String? waveformData,
  }) {
    return AttachmentPreview(
      id: id ?? this.id,
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      localPath: localPath ?? this.localPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      uploadId: uploadId ?? this.uploadId,
      state: state ?? this.state,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      waveformData: waveformData ?? this.waveformData,
    );
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Attachment preview tray widget
/// 
/// Shows selected attachments BEFORE sending with:
/// - Remove buttons
/// - Upload progress bars  
/// - State badges
/// - Type-specific previews
class AttachmentPreviewTray extends StatefulWidget {
  final List<AttachmentPreview> attachments;
  final Function(String) onRemoveAttachment;
  final Function(String)? onRetryUpload;

  const AttachmentPreviewTray({
    Key? key,
    required this.attachments,
    required this.onRemoveAttachment,
    this.onRetryUpload,
  }) : super(key: key);

  @override
  State<AttachmentPreviewTray> createState() => _AttachmentPreviewTrayState();
}

class _AttachmentPreviewTrayState extends State<AttachmentPreviewTray> {
  List<AttachmentPreview> _attachments = [];

  @override
  void initState() {
    super.initState();
    _attachments = widget.attachments;
  }

  @override
  void didUpdateWidget(AttachmentPreviewTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachments != oldWidget.attachments) {
      setState(() {
        _attachments = widget.attachments;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length,
        itemBuilder: (context, index) {
          final attachment = _attachments[index];
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 8),
            child: _AttachmentTile(
              attachment: attachment,
              onRemove: () => widget.onRemoveAttachment(attachment.id),
              onRetry: attachment.state == AttachmentState.failed
                  ? widget.onRetryUpload
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// Individual attachment tile with preview and controls
class _AttachmentTile extends StatelessWidget {
  final AttachmentPreview attachment;
  final VoidCallback onRemove;
  final Function(String)? onRetry;

  const _AttachmentTile({
    required this.attachment,
    required this.onRemove,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          // Preview content
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPreviewContent(),
            ),
          ),

          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),

          // State badge
          Positioned(
            bottom: 4,
            left: 4,
            child: _buildStateBadge(),
          ),

          // Progress bar (only show during upload)
          if (attachment.state == AttachmentState.uploading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: attachment.uploadProgress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    switch (attachment.type) {
      case AttachmentType.image:
        if (attachment.localPath != null) {
          // Check if it's a web bytes marker or file path
          if (attachment.localPath!.startsWith('web-bytes://')) {
            // For web bytes, show image icon
            return Container(
              color: Colors.blue[50],
              child: Icon(
                Icons.image,
                color: Colors.blue[700],
                size: 32,
              ),
            );
          } else {
            // Native file path - load actual image
            try {
              return Image.file(
                File(attachment.localPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFileIcon(),
              );
            } catch (e) {
              return _buildFileIcon();
            }
          }
        }
        return _buildFileIcon();

      case AttachmentType.video:
        return Stack(
          children: [
            if (attachment.thumbnailPath != null)
              Image.file(
                File(attachment.thumbnailPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFileIcon(),
              )
            else
              _buildFileIcon(),
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        );

      case AttachmentType.voice:
        return Container(
          color: Colors.blue[50],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mic,
                color: Colors.blue[700],
                size: 32,
              ),
              if (attachment.voiceDurationSeconds != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatDuration(attachment.voiceDurationSeconds!),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );

      case AttachmentType.file:
        return _buildFileIcon();
    }
  }

  Widget _buildFileIcon() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: Colors.grey[600],
            size: 32,
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              attachment.fileName,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            attachment.formattedFileSize,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateBadge() {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData? icon;

    switch (attachment.state) {
      case AttachmentState.uploading:
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        text = 'Uploading';
        icon = Icons.cloud_upload;
        break;
      case AttachmentState.uploaded:
      case AttachmentState.ready:
        backgroundColor = Colors.green;
        textColor = Colors.white;
        text = 'Ready';
        icon = Icons.check_circle;
        break;
      case AttachmentState.failed:
        backgroundColor = Colors.red;
        textColor = Colors.white;
        text = 'Failed';
        icon = Icons.error;
        break;
      default:
        backgroundColor = Colors.grey;
        textColor = Colors.white;
        text = 'Pending';
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 10,
              color: textColor,
            ),
          if (icon != null) const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 8,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
