import 'package:flutter/material.dart';
import '../models/message_model.dart';
import 'package:fs_hub/core/utils/url_utils.dart';
import 'package:fs_hub/shared/widgets/authenticated_image.dart';

class MediaMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MediaMessageBubble({super.key, required this.message, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(borderRadius: radius, color: Color(0xFF121212)),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message.meta != null && message.meta!['thumb'] != null)
                AuthenticatedImage(
                  url: UrlUtils.ensureAbsoluteUrl(message.meta!['thumb']), 
                  fit: BoxFit.cover
                ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(message.content, style: TextStyle(color: Colors.white70, fontSize: 13)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

