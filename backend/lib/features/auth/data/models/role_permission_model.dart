class RoleModel {
  final int? id;
  final String nom;
  final String? description;
  final DateTime? createdAt;

  RoleModel({
    this.id,
    required this.nom,
    this.description,
    this.createdAt,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      nom: json['nom']?.toString() ?? '',
      description: json['description']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'nom': nom,
      'description': description,
    };
  }

  RoleModel copyWith({
    int? id,
    String? nom,
    String? description,
    DateTime? createdAt,
  }) {
    return RoleModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'RoleModel(id: $id, nom: $nom)';
  }
}

class PermissionModel {
  final int? id;
  final String nom;
  final String? module;
  final String? description;
  final DateTime? createdAt;

  PermissionModel({
    this.id,
    required this.nom,
    this.module,
    this.description,
    this.createdAt,
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      nom: json['nom']?.toString() ?? '',
      module: json['module']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'module': module,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'nom': nom,
      'module': module,
      'description': description,
    };
  }

  PermissionModel copyWith({
    int? id,
    String? nom,
    String? module,
    String? description,
    DateTime? createdAt,
  }) {
    return PermissionModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      module: module ?? this.module,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'PermissionModel(id: $id, nom: $nom, module: $module)';
  }
}

class RolePermissionModel {
  final int? roleId;
  final int? permissionId;

  RolePermissionModel({
    this.roleId,
    this.permissionId,
  });

  factory RolePermissionModel.fromJson(Map<String, dynamic> json) {
    return RolePermissionModel(
      roleId: json['role_id'] != null ? int.tryParse(json['role_id'].toString()) : null,
      permissionId: json['permission_id'] != null ? int.tryParse(json['permission_id'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role_id': roleId,
      'permission_id': permissionId,
    };
  }
}
