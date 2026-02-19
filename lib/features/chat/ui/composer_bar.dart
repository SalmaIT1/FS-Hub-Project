import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:typed_data';
import '../domain/message_state_machine.dart' as chat_domain;
import '../../uploads/services/attachment_manager.dart';
import '../../uploads/widgets/attachment_preview_tray.dart';
import '../../../chat/ui/voice_recorder.dart';
import '../../../core/state/settings_controller.dart';

/// Enhanced composer bar with full attachment support
/// 
/// Features:
/// - Text input with multiline support
/// - Attachment preview tray above composer
/// - File/image/voice picker integration
/// - Send button (disabled until text/attachments ready)
/// - Voice recording with waveform preview
/// - Real-time upload progress tracking
class ComposerBar extends StatefulWidget {
  final String conversationId;
  final Function(String, List<String>, {Map<String, dynamic>? voiceMetadata}) onSendMessage;
  final AttachmentManager attachmentManager;

  const ComposerBar({
    Key? key,
    required this.conversationId,
    required this.onSendMessage,
    required this.attachmentManager,
  }) : super(key: key);

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  late TextEditingController _textController;
  bool _hasText = false;
  bool _showVoiceRecorder = false;
  List<AttachmentPreview> _attachments = [];
  StreamSubscription? _attachmentSubscription;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(_onTextChanged);
    
    // Listen to attachment changes
    _attachmentSubscription = widget.attachmentManager.attachments.listen((attachments) {
      setState(() {
        _attachments = attachments;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _attachmentSubscription?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _textController.text.trim().isNotEmpty;
    });
  }

  bool get _canSend {
    // Can send if there's text or attachments, and none are in failed state
    final hasContent = _hasText || _attachments.isNotEmpty;
    if (!hasContent) return false;
    
    // Block sending only if attachments are in failed state
    final hasFailedAttachments = _attachments.any(
      (a) => a.state == chat_domain.AttachmentState.failed
    );
    
    return !hasFailedAttachments;
  }


  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Column(
      children: [
        // Voice recorder (shown when activated)
        if (_showVoiceRecorder)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: VoiceRecorder(
              onRecordingComplete: (audioPath, durationSeconds, waveformData, bytes) {
                // Convert JSArray to Uint8List for web
                Uint8List? convertedBytes;
                if (bytes != null) {
                  if (bytes is Uint8List) {
                    convertedBytes = bytes;
                  } else if (bytes is List<int>) {
                    convertedBytes = Uint8List.fromList(bytes);
                  } else {
                    print('[ComposerBar] Unexpected bytes type: ${bytes.runtimeType}');
                    convertedBytes = null;
                  }
                }
                
                widget.attachmentManager.addVoiceRecording(
                  audioPath: audioPath,
                  durationSeconds: durationSeconds,
                  waveformData: waveformData,
                  bytes: convertedBytes,
                );
                setState(() {
                  _showVoiceRecorder = false;
                });
              },
            ),
          ),

        // Attachment preview tray
        AttachmentPreviewTray(
          attachments: _attachments,
          onRemoveAttachment: widget.attachmentManager.removeAttachment,
          onRetryUpload: (attachmentId) => widget.attachmentManager.retryUpload(attachmentId),
        ),

        // Composer bar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              // Attachment button
              IconButton(
                icon: const Icon(Icons.attachment),
                onPressed: () => _showAttachmentMenu(settings),
              ),

              // Text input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: settings.translate('message_hint'),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(settings),
                  ),
                ),
              ),

              // Send button
              IconButton(
                icon: Icon(
                  Icons.send,
                  color: _canSend ? Colors.blue : Colors.grey,
                ),
                onPressed: _canSend ? () => _send(settings) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAttachmentMenu(SettingsController settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(settings.translate('camera')),
              onTap: () {
                Navigator.pop(context);
                widget.attachmentManager.selectImages(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: Text(settings.translate('gallery')),
              onTap: () {
                Navigator.pop(context);
                widget.attachmentManager.selectImages(fromCamera: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(settings.translate('file')),
              onTap: () {
                Navigator.pop(context);
                widget.attachmentManager.selectFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: Text(settings.translate('voice_recording')),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _showVoiceRecorder = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(SettingsController settings) async {
    if (!_canSend) return;

    final text = _textController.text.trim();
    
    try {
      final uploadResult = await widget.attachmentManager.uploadAllAttachments();
      final uploadIds = uploadResult['uploadIds'] as List<String>;
      final voiceMetadata = uploadResult['voiceMetadata'] as Map<String, dynamic>?;
      
      // Check if there's content to send (text or uploaded attachments)
      if (text.isNotEmpty || uploadIds.isNotEmpty) {
        widget.onSendMessage(text, uploadIds, voiceMetadata: voiceMetadata);
        
        // Clear UI
        _textController.clear();
        setState(() {
          _hasText = false;
        });
        
        // Clear attachments after successful send
        await widget.attachmentManager.clearAllAttachments();
      } else {
        // Show error if nothing to send (attachments may have all failed)
        if (_attachments.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(settings.translate('upload_failed')),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
