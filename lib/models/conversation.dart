class Conversation {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final String otherParticipantId;
  final String otherParticipantName;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    required this.otherParticipantId,
    required this.otherParticipantName,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'].toString(),
      participant1Id: json['participant1Id'].toString(),
      participant2Id: json['participant2Id'].toString(),
      otherParticipantId: json['otherParticipantId'].toString(),
      otherParticipantName: json['otherParticipantName'] ?? 'Unknown',
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null 
          ? DateTime.parse(json['lastMessageTime']) 
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant1Id': participant1Id,
      'participant2Id': participant2Id,
      'otherParticipantId': otherParticipantId,
      'otherParticipantName': otherParticipantName,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
