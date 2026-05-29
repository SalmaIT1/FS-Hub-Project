import 'dart:convert';

import 'package:fs_hub_backend/features/auth/domain/services/auth_service.dart';
import 'package:fs_hub_backend/features/chat/presentation/websocket/websocket_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('WebSocketServer — ticket auth', () {
    late WebSocketServer server;

    setUp(() {
      AuthService.initSecretForTests('ws-unit-test-secret-min-32-chars');
      server = WebSocketServer();
    });

    test('rejects handshake without ticket', () async {
      final response = await server.router.call(
        Request('GET', Uri.parse('http://localhost/')),
      );
      expect(response.statusCode, 401);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['message'], contains('ticket'));
    });

    test('rejects invalid or reused ticket', () async {
      final bad = await server.router.call(
        Request('GET', Uri.parse('http://localhost/?ticket=not-valid')),
      );
      expect(bad.statusCode, 403);

      final ticket = AuthService.issueWsTicket('user-ws-1', 'Admin');
      final first = await server.router.call(
        Request('GET', Uri.parse('http://localhost/?ticket=$ticket')),
      );
      expect(first.statusCode, isNot(403));

      final second = await server.router.call(
        Request('GET', Uri.parse('http://localhost/?ticket=$ticket')),
      );
      expect(second.statusCode, 403);
    });
  });
}
