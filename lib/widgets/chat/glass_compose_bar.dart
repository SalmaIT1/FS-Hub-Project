import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';

class GlassComposeBar extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onEmojiTap;
  final Function(String)? onMessageSent;

  const GlassComposeBar({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    this.onAttachmentTap,
    this.onEmojiTap,
    this.onMessageSent,
  });

  @override
  State<GlassComposeBar> createState() => _GlassComposeBarState();
}

class _GlassComposeBarState extends State<GlassComposeBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isRecording = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    VoiceRecorder.cancelRecording();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text.trim();
    final wasTyping = _isTyping;
    _isTyping = text.isNotEmpty;

    if (wasTyping != _isTyping) {
      if (_isTyping) {
        ChatService.startTyping(widget.conversationId);
      } else {
        ChatService.stopTyping(widget.conversationId);
      }
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        ChatService.stopTyping(widget.conversationId);
        setState(() => _isTyping = false);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Clear input immediately for better UX
    _textController.clear();
    setState(() => _isTyping = false);
    ChatService.stopTyping(widget.conversationId);

    // Send message
    final message = await ChatService.sendMessage(
      conversationId: widget.conversationId,
      content: text,
      type: 'text',
      senderId: widget.currentUserId,
    );

    if (message != null) {
      widget.onMessageSent?.call(message['id'] as String);
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileId = await ChatService.uploadFile(file);
        
        if (fileId != null) {
          // Send file message
          await ChatService.sendMessage(
            conversationId: widget.conversationId,
            content: result.files.single.name,
            type: 'file',
            senderId: widget.currentUserId,
          );
          
          HapticFeedback.lightImpact();
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _startRecording() async {
    final started = await VoiceRecorder.startRecording();
    if (started) {
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });

      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    
    final result = await VoiceRecorder.stopRecording();
    if (result != null) {
      // Send voice message
      await ChatService.sendMessage(
        conversationId: widget.conversationId,
        content: 'Voice message (${result['duration'] as String})',
        type: 'voice',
        senderId: widget.currentUserId,
      );
      
      HapticFeedback.lightImpact();
    }

    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });
  }

  void _cancelRecording() {
    _recordingTimer?.cancel();
    VoiceRecorder.cancelRecording();
    
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });
    
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              if (_isRecording) _buildRecordingIndicator(),
              _buildComposeRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Recording... ${_formatDuration(_recordingDuration)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                size: 20,
                color: Colors.red.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeRow() {
    return Row(
      children: [
        _buildLeadingButton(),
        Expanded(child: _buildTextField()),
        _buildTrailingButton(),
      ],
    );
  }

  Widget _buildLeadingButton() {
    if (_isRecording) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        child: GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.stop,
              color: Colors.red.withOpacity(0.8),
              size: 24,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: widget.onAttachmentTap ?? _pickFile,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.attach_file,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Type a message...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 12,
          ),
        ),
        maxLines: 5,
        minLines: 1,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _sendMessage(),
      ),
    );
  }

  Widget _buildTrailingButton() {
    final hasText = _textController.text.trim().isNotEmpty;

    if (hasText) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentGold.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.send,
              color: AppTheme.accentGold.withOpacity(0.9),
              size: 20,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTapDown: (_) => _startRecording(),
        onTapUp: (_) => _stopRecording(),
        onTapCancel: _cancelRecording,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.mic,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
