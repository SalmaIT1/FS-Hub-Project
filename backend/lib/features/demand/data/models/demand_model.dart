class DemandModel {
  final String id;
  final String type;
  final String description;
  final String status;
  final String requesterId;
  final String? requesterName;
  final String? handledBy;
  final String? resolutionNotes;
  final String? createdAt;
  final String? updatedAt;

  DemandModel({
    required this.id,
    required this.type,
    required this.description,
    required this.status,
    required this.requesterId,
    this.requesterName,
    this.handledBy,
    this.resolutionNotes,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'status': status,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'handledBy': handledBy,
      'resolutionNotes': resolutionNotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DemandModel.fromMap(Map<String, dynamic> map) {
    return DemandModel(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      requesterId: map['requester_id']?.toString() ?? '',
      requesterName: map['requester_name']?.toString(),
      handledBy: map['handled_by']?.toString(),
      resolutionNotes: map['resolution_notes']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }
}
