class Conversation {
  final String id;
  final String title;
  final List<String> participantIds;
  final int lastActivity;
  final bool isGroup;

  Conversation({
    required this.id,
    required this.title,
    required this.participantIds,
    required this.lastActivity,
    this.isGroup = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'],
        title: j['title'] ?? '',
        participantIds: List<String>.from(j['participantIds'] ?? []),
        lastActivity: j['lastActivity'] ?? 0,
        isGroup: j['isGroup'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'participantIds': participantIds,
        'lastActivity': lastActivity,
        'isGroup': isGroup,
      };
}
