import 'package:flutter/material.dart';

/// Composer bar for message input
/// 
/// Features:
/// - Text input with multiline support
/// - File picker button
/// - Image picker button
/// - Send button (disabled until text/attachment)
/// - Draft persistence (future enhancement)
/// - Keyboard-safe layout
class ComposerBar extends StatefulWidget {
  final String conversationId;
  final Function(String) onSend;
  final VoidCallback? onAttachmentSelected;

  const ComposerBar({
    Key? key,
    required this.conversationId,
    required this.onSend,
    this.onAttachmentSelected,
  }) : super(key: key);

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  late TextEditingController _textController;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _textController.text.trim().isNotEmpty;
    });
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _textController.clear();
      _hasText = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: Icon(Icons.attachment),
            onPressed: () {
              _showAttachmentMenu();
            },
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
                  hintText: 'Message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),

          // Send button
          IconButton(
            icon: Icon(
              Icons.send,
              color: _hasText ? Colors.blue : Colors.grey,
            ),
            onPressed: _hasText ? _send : null,
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.image),
              title: Text('Image'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Image picker
                widget.onAttachmentSelected?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file),
              title: Text('File'),
              onTap: () {
                Navigator.pop(context);
                // TODO: File picker
                widget.onAttachmentSelected?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.mic),
              title: Text('Voice'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Voice recorder
                widget.onAttachmentSelected?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
