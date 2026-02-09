import 'dart:convert';

enum MessageType { text, image, file, audio, system }

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String content;
  final int timestamp; // epoch ms
  final bool read;
  final Map<String, dynamic>? meta;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.content,
    required this.timestamp,
    this.read = false,
    this.meta,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'],
        conversationId: j['conversationId'],
        senderId: j['senderId'],
        type: MessageType.values.firstWhere((e) => e.toString() == 'MessageType.' + (j['type'] ?? 'text')),
        content: j['content'] ?? '',
        timestamp: j['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        read: j['read'] ?? false,
        meta: j['meta'] == null ? null : Map<String, dynamic>.from(j['meta']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'type': type.toString().split('.').last,
        'content': content,
        'timestamp': timestamp,
        'read': read,
        'meta': meta,
      };

  @override
  String toString() => jsonEncode(toJson());
}
