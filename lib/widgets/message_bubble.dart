import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool compact; // true when grouped with previous message

  MessageBubble({required this.message, this.isMe = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? Color(0xFF101010) : Color(0xFF1A1A1A);
    final borderRadius = BorderRadius.circular(22);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(top: compact ? 2 : 8, bottom: 6, left: 12, right: 12),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(color: bg, borderRadius: borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContent(),
            SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatTime(message.timestamp), style: TextStyle(color: Colors.white38, fontSize: 11)),
                if (isMe) ...[
                  SizedBox(width: 8),
                  Icon(message.read ? Icons.done_all : Icons.check, size: 14, color: message.read ? Color(0xFFFFD700) : Colors.white38),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (message.type) {
      case MessageType.text:
        return Text(message.content, style: TextStyle(color: Colors.white, fontSize: 15, height: 1.2));
      default:
        return Text('[${message.type.toString().split('.').last}]', style: TextStyle(color: Colors.white70));
    }
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
