class AuditLog {
  final int id;
  final String userId;
  final String action;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String? userName;
  final String? userEmail;

  AuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.details,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details']) : {},
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      userName: json['user_name']?.toString(),
      userEmail: json['user_email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'details': details,
      'created_at': createdAt.toIso8601String(),
      'user_name': userName,
      'user_email': userEmail,
    };
  }
}
