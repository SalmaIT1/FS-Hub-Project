import 'package:flutter/material.dart';
import '../models/message.dart';

class VoiceMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  VoiceMessageBubble({required this.message, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: Color(0xFFFFD700)),
            SizedBox(width: 8),
            Text(message.meta?['duration'] ?? 'Voice', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
