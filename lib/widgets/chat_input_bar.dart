import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/chat/state/chat_controller.dart';
import 'package:fs_hub/services/real_audio_recorder.dart';
import 'package:fs_hub/features/voice/services/waveform_generator.dart';
import 'package:just_audio/just_audio.dart';
import '../shared/models/message_model.dart';
import '../core/localization/translations.dart';
import '../core/state/settings_controller.dart';
import 'media_picker_sheet.dart';
import 'upload_progress_overlay.dart';

typedef OnSend = void Function(String text, List<Map<String, dynamic>> attachments);

class ChatInputBar extends StatefulWidget {
  final OnSend onSend;
  ChatInputBar({required this.onSend});

  @override
  _ChatInputBarState createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  int _lines = 1;
  bool _sending = false;
  bool _showUpload = false;
  double _uploadProgress = 0.0;
  final _recorder = RealAudioRecorder();
  StreamSubscription? _durationSub;
  bool _recording = false;
  bool _cancelRecording = false;

  // PERSISTED STATE - Store recording data
  String? _recordedFilePath;
  double _durationSeconds = 0;
  io.File? _recordedFile;

  void _onChanged() {
    final lines = '\n'.allMatches(_ctrl.text).length + 1;
    setState(() => _lines = lines.clamp(1, 5));
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    _requestRecordingPermission();
  }

  Future<void> _requestRecordingPermission() async {
    try {
      await _recorder.requestPermission();
    } catch (e) {
      
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _durationSub?.cancel();
    _recorder.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final languageCode = settings.languageCode;
    
    return Stack(
      children: [
        Container(
          color: Color(0x0A111111),
          padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.attach_file, color: Colors.white70), onPressed: _openPicker),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 20.0 * 5 + 20),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: 5,
                      minLines: 1,
                      style: TextStyle(color: Colors.white, fontSize: 15, height: 1.2),
                      decoration: InputDecoration(
                        hintText: Translations.getText('message_hint', languageCode),
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        filled: true,
                        fillColor: Color(0xFF111111),
                        enabled: !_sending && !_recording,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending || _recording ? null : _send,
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressMoveUpdate: (m) => _handleLongPressMove(m.globalPosition.dx),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Color(0xFFFFD700), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_recording ? Icons.mic : Icons.send, color: Colors.black),
                  ),
                )
              ],
            ),
          ),
        ),
        if (_showUpload) Positioned.fill(child: UploadProgressOverlay(progress: _uploadProgress, label: Translations.getText('uploading', languageCode))),
        if (_recording) Positioned.fill(child: _buildRecordingOverlay()),
      ],
    );
  }

  Widget _buildRecordingOverlay() {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
          ),
          child: StreamBuilder<double>(
            stream: _recorder.durationUpdates,
            initialData: 0,
            builder: (ctx, snap) {
              final secs = snap.data ?? 0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red[500]!.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(Icons.mic, size: 40, color: Colors.red[500]),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text(
                    '${(secs.toInt() ~/ 60).toString().padLeft(1, '0')}:${(secs.toInt() % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _cancelRecording ? Translations.getText('slide_to_cancel', languageCode) : Translations.getText('recording', languageCode),
                    style: TextStyle(
                      color: _cancelRecording ? Colors.orange : Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MediaPickerSheet(
        onPick: (type) async {
          if (type == 'image' || type == 'file' || type == 'camera') {
            
          }
        },
      ),
    );
  }

  void _handleLongPressMove(double globalDx) {
    final w = MediaQuery.of(context).size.width;
    setState(() => _cancelRecording = globalDx < w * 0.25);
  }

  void _startRecording() async {
    try {
      
      setState(() {
        _recording = true;
        _cancelRecording = false;
      });
      await _recorder.start();
      
    } catch (e) {
      
      _showError(Translations.getText('failed_to_start_recording', languageCode) + ': $e');
      setState(() => _recording = false);
    }
  }

  void _stopRecording() async {
    if (!_recording) return;

    setState(() => _recording = false);

    if (_cancelRecording) {
      try {
        await _recorder.cancel();
        
      } catch (e) {
        
      }
      return;
    }

    // Recording completed - process and show preview
    try {
      
      final result = await _recorder.stop();
      if (result == null) {
        _showError(Translations.getText('failed_to_save_recording', languageCode));
        return;
      }

      // PERSIST recording data
      _recordedFilePath = result.filePath;
      _recordedFile = io.File(result.filePath);
      _durationSeconds = result.durationMs / 1000.0;

      

      // Verify file exists and has data
      if (!await _recordedFile!.exists()) {
        _showError(Translations.getText('recording_file_does_not_exist', languageCode));
        _recordedFilePath = null;
        _recordedFile = null;
        return;
      }

      final fileSize = await _recordedFile!.length();


      if (fileSize == 0) {
        _showError(Translations.getText('recording_is_empty', languageCode));
        _recordedFilePath = null;
        _recordedFile = null;
        return;
      }

      // Show preview dialog
      if (mounted) {
        _showPreviewDialog();
      }
    } catch (e) {

      _showError('Error processing recording: $e');
      _recordedFilePath = null;
      _recordedFile = null;
    }
  }

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (_) => _VoicePreviewDialog(
        filePath: _recordedFilePath!,
        durationSeconds: _durationSeconds,
        onSend: _sendVoiceNote,
        onDiscard: () {
          _recordedFilePath = null;
          _recordedFile = null;
          _durationSeconds = 0;
        },
      ),
    );
  }

  Future<void> _sendVoiceNote() async {
    try {
      // CRITICAL VALIDATION
      if (_recordedFilePath == null || _recordedFilePath!.isEmpty) {
        _showError(Translations.getText('no_recording_to_send', languageCode));
        return;
      }

      if (_recordedFile == null) {
        _showError(Translations.getText('file_reference_lost', languageCode));
        return;
      }

      if (!await _recordedFile!.exists()) {
        _showError(Translations.getText('recording_file_was_deleted', languageCode));
        _recordedFilePath = null;
        _recordedFile = null;
        return;
      }

      final fileSize = await _recordedFile!.length();
      

      if (fileSize == 0) {
        _showError(Translations.getText('recording_is_empty', languageCode));
        return;
      }

      // Read file bytes
      final audioBytes = await _recordedFile!.readAsBytes();
      

      // Generate waveform data
      String waveformData = '';
      try {
        waveformData = WaveformGenerator.generateWaveformFromM4A(audioBytes);

      } catch (e) {

        // Continue without waveform - it's optional
      }



      setState(() => _showUpload = true);
      final controller = context.read<ChatController>();

      await controller.sendVoiceNote(
        audioFilePath: _recordedFilePath!,
        audioBytes: audioBytes,
        durationMs: (_durationSeconds * 1000).toInt(),
        waveformData: waveformData,
        onUploadProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      print('[ChatInputBar._sendVoiceNote] Success');

      // Clear recording state
      _recordedFilePath = null;
      _recordedFile = null;
      _durationSeconds = 0;

      if (mounted) {
        Navigator.of(context).pop(); // Close preview if still open
        setState(() {
          _showUpload = false;
          _uploadProgress = 0.0;
        });
      }
    } catch (e) {
      print('[ChatInputBar._sendVoiceNote] Error: $e');
      _showError(Translations.getText('failed_to_send_voice_note', languageCode) + ': $e');
    }
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    widget.onSend(text, []);
    _ctrl.clear();
    setState(() => _sending = false);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Real voice preview dialog with actual playback
class _VoicePreviewDialog extends StatefulWidget {
  final String filePath;
  final double durationSeconds;
  final VoidCallback onSend;
  final VoidCallback onDiscard;

  const _VoicePreviewDialog({
    required this.filePath,
    required this.durationSeconds,
    required this.onSend,
    required this.onDiscard,
  });

  @override
  State<_VoicePreviewDialog> createState() => _VoicePreviewDialogState();
}

class _VoicePreviewDialogState extends State<_VoicePreviewDialog> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupAudio();
  }

  Future<void> _setupAudio() async {
    try {
      _audioPlayer = AudioPlayer();

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });

      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() => _currentPosition = position);
        }
      });

      _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _totalDuration = duration);
        }
      });

      print('[VoicePreview] Loading: ${widget.filePath}');
      final file = io.File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }
      final size = await file.length();
      print('[VoicePreview] File size: $size bytes');

      await _audioPlayer.setFilePath(widget.filePath);
      print('[VoicePreview] Audio loaded successfully');
    } catch (e) {
      print('[VoicePreview] Setup error: $e');
      if (mounted) {
        setState(() => _error = Translations.getText('failed_to_load_audio', languageCode) + ': $e');
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('[VoicePreview] Play error: $e');
      if (mounted) {
        setState(() => _error = Translations.getText('playback_error', languageCode) + ': $e');
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final languageCode = settings.languageCode;
    
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Translations.getText('voice_message', languageCode),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            if (_error == null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(Duration(seconds: widget.durationSeconds.toInt())),
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Player controls
              Row(
                children: [
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _totalDuration.inMilliseconds > 0
                                ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                                : 0,
                            backgroundColor: Colors.grey[700],
                            valueColor: AlwaysStoppedAnimation(const Color(0xFFFFD700)),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            Text(
                              _formatDuration(_totalDuration),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDiscard();
                  },
                  icon: const Icon(Icons.close, size: 20),
                  label: Text(Translations.getText('discard', languageCode)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[400]!),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _error != null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onSend();
                        },
                  icon: const Icon(Icons.send, size: 20),
                  label: Text(Translations.getText('send', languageCode)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black87,
                    disabledBackgroundColor: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
