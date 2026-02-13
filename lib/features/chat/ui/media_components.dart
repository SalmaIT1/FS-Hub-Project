import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:fs_hub/utils/web_download_stub.dart'
  if (dart.library.html) 'package:fs_hub/utils/web_download_web.dart';
import '../../../chat/domain/chat_entities.dart';
import '../../../chat/ui/adaptive_voice_note.dart';
import '../../../chat/ui/whatsapp_voice_note.dart';

/// Simple image bubble: inline thumbnail, tap to open modal full-screen.
class InlineImageBubble extends StatelessWidget {
  final AttachmentEntity attachment;
  final double maxSize;

  const InlineImageBubble({Key? key, required this.attachment, this.maxSize = 200}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final url = attachment.uploadUrl;
    return GestureDetector(
      onTap: () {
        if (url.isEmpty) return;
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: Container(
        width: maxSize,
        height: maxSize,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[200]),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(child: CircularProgressIndicator());
          },
          errorBuilder: (c, e, st) => Center(child: Icon(Icons.broken_image, size: 48)),
        ),
      ),
    );
  }
}

/// File attachment bubble: shows filename, size, icon; downloads and opens on tap.
class FileAttachmentBubble extends StatelessWidget {
  final AttachmentEntity attachment;

  const FileAttachmentBubble({Key? key, required this.attachment}) : super(key: key);

  Future<void> _downloadAndOpen(BuildContext context) async {
    final url = attachment.uploadUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No file URL')));
      return;
    }

    // Show progress dialog
    final progress = ValueNotifier<double>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DownloadProgressOverlay(notifier: progress, filename: attachment.filename),
    );

    try {
      // Try web download helper first (on web this will perform a browser download).
      try {
        await webTriggerDownload(url, attachment.filename);
        Navigator.of(context).pop();
        return;
      } catch (e) {
        // If web helper is not supported on this platform, continue with native download flow.
      }

      final req = http.Request('GET', Uri.parse(url));
      final streamed = await req.send();
      if (streamed.statusCode != 200) {
        throw Exception('Failed to download file: HTTP ${streamed.statusCode}');
      }

      final total = streamed.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/${attachment.filename}';
      final file = io.File(savePath);
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in streamed.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) progress.value = received / total;
      }
      await sink.close();

      Navigator.of(context).pop();
      await OpenFilex.open(savePath);
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    } finally {
      progress.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = attachment.filename.isNotEmpty ? attachment.filename : 'file';
    // If this is audio, render WhatsApp-style player instead of download tile
    if (attachment.mimeType.startsWith('audio/')) {
      return WhatsAppVoiceNote(
        voice: VoiceNoteEntity(
          id: attachment.id,
          uploadUrl: attachment.uploadUrl,
          durationMs: attachment.size > 0 ? attachment.size * 10 : 5000, // Estimate duration
          recordedAt: DateTime.now(),
          waveformData: '', // Empty waveform for now
        ),
        isSentByMe: false, // You can pass this from parent widget
      );
    }

    return ListTile(
      onTap: () => _downloadAndOpen(context),
      leading: _fileIcon(attachment.mimeType),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_formatSize(attachment.size)),
    );
  }

  Widget _fileIcon(String mime) {
    if (mime.startsWith('image/')) return Icon(Icons.photo);
    if (mime.startsWith('video/')) return Icon(Icons.videocam);
    if (mime.startsWith('audio/')) return Icon(Icons.audiotrack);
    return Icon(Icons.insert_drive_file);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Voice note bubble: now uses adaptive format handling widget
class VoiceNoteBubble extends StatelessWidget {
  final VoiceNoteEntity voice;
  final bool isSentByMe;
  final Color? bubbleColor;

  const VoiceNoteBubble({
    Key? key, 
    required this.voice, 
    this.isSentByMe = false,
    this.bubbleColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdaptiveVoiceNote(
      voice: voice,
      isSentByMe: isSentByMe,
      bubbleColor: bubbleColor,
    );
  }
}

/// Download progress dialog
class DownloadProgressOverlay extends StatelessWidget {
  final ValueNotifier<double> notifier;
  final String filename;
  const DownloadProgressOverlay({Key? key, required this.notifier, required this.filename}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Downloading $filename'),
      content: ValueListenableBuilder<double>(
        valueListenable: notifier,
        builder: (_, v, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: v),
            SizedBox(height: 12),
            Text('${(v * 100).toStringAsFixed(0)}%')
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
      ],
    );
  }
}
