class PermissionsGuard {
  final String userId;
  final List<String> roles;

  PermissionsGuard({required this.userId, required this.roles});

  bool canSend(String conversationId) {
    // role-based checks; production: query server
    return roles.contains('chat:send') || roles.contains('admin');
  }

  bool canUpload() {
    return roles.contains('chat:upload') || roles.contains('admin');
  }
}
