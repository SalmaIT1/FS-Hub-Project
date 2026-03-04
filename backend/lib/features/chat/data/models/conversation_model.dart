class ConversationModel {
  final String id;
  final String? name;
  final String type;
  final String? avatarUrl;
  final String? receiverId;
  final bool isOnline;
  final String? createdAt;
  final String? updatedAt;
  final String? lastMessageAt;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final String? lastMessageSenderName;
  final int unreadCount;
  final List<String> participantIds;

  ConversationModel({
    required this.id,
    this.name,
    required this.type,
    this.avatarUrl,
    this.receiverId,
    required this.isOnline,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    required this.unreadCount,
    this.participantIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'avatarUrl': avatarUrl,
      'receiverId': receiverId,
      'isOnline': isOnline,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastMessageAt': lastMessageAt,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageSenderName': lastMessageSenderName,
      'unreadCount': unreadCount,
      'participantIds': participantIds,
    };
  }
}
