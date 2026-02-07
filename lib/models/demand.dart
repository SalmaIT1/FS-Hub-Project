class Demand {
  final String id;
  final String type;
  final String description;
  final String requesterId;
  final String requesterName;
  final String status;
  final String createdAt;
  final String? handledBy;
  final String? handlerName;
  final String? resolutionNotes;

  Demand({
    required this.id,
    required this.type,
    required this.description,
    required this.requesterId,
    required this.requesterName,
    required this.status,
    required this.createdAt,
    this.handledBy,
    this.handlerName,
    this.resolutionNotes,
  });

  factory Demand.fromJson(Map<String, dynamic> json) {
    return Demand(
      id: json['id'].toString(),
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['createdAt'] ?? '',
      handledBy: json['handledBy'],
      handlerName: json['handlerName'],
      resolutionNotes: json['resolutionNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'status': status,
      'createdAt': createdAt,
      'handledBy': handledBy,
      'handlerName': handlerName,
      'resolutionNotes': resolutionNotes,
    };
  }
}