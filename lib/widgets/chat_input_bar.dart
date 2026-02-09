import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/chat/state/chat_controller.dart';
import '../models/message.dart';
import 'media_picker_sheet.dart';
import '../services/audio_recorder_controller.dart';
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
  final _recorder = AudioRecorderController();
  StreamSubscription<double>? _recSub;
  bool _recording = false;
  bool _cancelRecording = false;

  void _onChanged() {
    final lines = '\n'.allMatches(_ctrl.text).length + 1;
    setState(() => _lines = lines.clamp(1, 5));
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _recSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        hintText: 'Message',
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
        if (_showUpload) Positioned.fill(child: UploadProgressOverlay(progress: _uploadProgress, label: 'Uploading...')),
        if (_recording) Positioned.fill(child: _buildRecordingOverlay()),
      ],
    );
  }

  Widget _buildRecordingOverlay() {
    return Material(
      color: Colors.black45,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.circular(12)),
          child: StreamBuilder<double>(
            stream: _recorder.progress,
            builder: (ctx, snap) {
              final secs = snap.data?.toStringAsFixed(1) ?? '0.0';
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_cancelRecording ? 'Release to cancel' : 'Recording', style: TextStyle(color: Colors.white)),
                SizedBox(height: 12),
                LinearProgressIndicator(value: (snap.data ?? 0) % 60 / 60.0, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(Color(0xFFFFD700))),
                SizedBox(height: 8),
                Text('$secs s', style: TextStyle(color: Colors.white70)),
              ]);
            },
          ),
        ),
      ),
    );
  }

  void _openPicker() async {
    final controller = context.read<ChatController>();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => MediaPickerSheet(onPick: (type) async {
      if (type == 'image' || type == 'file' || type == 'camera') {
        // open native picker and prepare attachments list
        // For brevity, this demo calls REST upload flow via MessageService
      }
    }));
  }

  void _handleLongPressMove(double globalDx) {
    // If user swipes left quickly cancel
    // Simple heuristic: far left cancels
    final w = MediaQuery.of(context).size.width;
    setState(() => _cancelRecording = globalDx < w * 0.25);
  }

  void _startRecording() async {
    setState(() {
      _recording = true;
      _cancelRecording = false;
    });
    await _recorder.start();
    _recSub = _recorder.progress.listen((p) {});
  }

  void _stopRecording() async {
    final path = await _recorder.stop();
    _recSub?.cancel();
    setState(() {
      _recording = false;
    });
    if (_cancelRecording) return; // dropped

    // send voice message via service
    final controller = context.read<ChatController>();
    setState(() => _showUpload = true);
    // For now, call sendMessage with empty text; attachment pipeline is handled by controller/repository in new module
    await controller.sendMessage('');
    setState(() {
      _showUpload = false;
      _uploadProgress = 0.0;
    });
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    widget.onSend(text, []);
    _ctrl.clear();
    setState(() => _sending = false);
  }
}
