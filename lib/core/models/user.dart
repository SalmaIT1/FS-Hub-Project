class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? token;
  final String? role;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.token,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
      token: json['token'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'token': token,
      'role': role,
    };
  }
}
