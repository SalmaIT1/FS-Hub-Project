class CreditModel {
  final int? id;
  final String type;
  final double montant;
  final DateTime dateCredit;
  final String? description;
  final int? clientId;
  final int? projectId;
  final int? invoiceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  CreditModel({
    this.id,
    required this.type,
    required this.montant,
    required this.dateCredit,
    this.description,
    this.clientId,
    this.projectId,
    this.invoiceId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory CreditModel.fromJson(Map<String, dynamic> json) {
    return CreditModel(
      id: json['id'] as int?,
      type: json['type'] as String,
      montant: (json['montant'] as num).toDouble(),
      dateCredit: DateTime.parse(json['date_credit'] as String),
      description: json['description'] as String?,
      clientId: json['client_id'] as int?,
      projectId: json['projet_id'] as int?,
      invoiceId: json['invoice_id'] as int?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'montant': montant,
      'date_credit': dateCredit.toIso8601String().split('T')[0],
      'description': description,
      'client_id': clientId,
      'projet_id': projectId,
      'invoice_id': invoiceId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'type': type,
      'montant': montant,
      'date_credit': dateCredit.toIso8601String().split('T')[0],
      'description': description,
      'client_id': clientId,
      'projet_id': projectId,
      'invoice_id': invoiceId,
      'created_by': createdBy,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final json = toCreateJson();
    if (id != null) json['id'] = id;
    return json;
  }

  CreditModel copyWith({
    int? id,
    String? type,
    double? montant,
    DateTime? dateCredit,
    String? description,
    int? clientId,
    int? projectId,
    int? invoiceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CreditModel(
      id: id ?? this.id,
      type: type ?? this.type,
      montant: montant ?? this.montant,
      dateCredit: dateCredit ?? this.dateCredit,
      description: description ?? this.description,
      clientId: clientId ?? this.clientId,
      projectId: projectId ?? this.projectId,
      invoiceId: invoiceId ?? this.invoiceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'CreditModel(id: $id, type: $type, montant: $montant, dateCredit: $dateCredit)';
  }
}
