import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';
import 'package:fs_hub/chat/data/chat_rest_client.dart';
import 'package:fs_hub/chat/data/chat_socket_client.dart';
import 'package:fs_hub/chat/data/upload_service.dart';
import 'package:fs_hub/chat/data/chat_repository.dart';
import 'package:fs_hub/chat/domain/chat_entities.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final baseUrl = const String.fromEnvironment('TEST_BASE_URL', defaultValue: 'http://localhost:8080');
  final jwt = const String.fromEnvironment('TEST_JWT', defaultValue: '');

  if (jwt.isEmpty) {
    // Skip the test if no JWT provided; user should run locally with --dart-define
    testWidgets('skip e2e (no TEST_JWT)', (WidgetTester tester) async {
      print('Skipping E2E: TEST_JWT not provided.');
    });
    return;
  }

  testWidgets('message send replaces temp with canonical', (WidgetTester tester) async {
    // Build chat clients and repository using the provided TEST_JWT
    final rest = ChatRestClient(baseUrl: baseUrl, tokenProvider: () async => jwt);
    final ws = ChatSocketClient(wsUrl: baseUrl.replaceFirst('http', 'ws').replaceFirst('/v1', '/ws'), tokenProvider: () async => jwt);
    final uploads = UploadService(baseUrl: baseUrl, tokenProvider: () async => jwt);
    final repo = ChatRepository(rest: rest, socket: ws, uploads: uploads);

    // Initialize repository (connect socket, etc.)
    await repo.init();

    final conversationId = '1';
    final senderId = '1';
    final content = 'E2E test message ${DateTime.now().millisecondsSinceEpoch}';

    // Send via repository (this creates optimistic message and will return server canonical when complete)
    final result = await repo.sendTextMessage(conversationId: conversationId, senderId: senderId, content: content);

    // Expect a server-assigned id and sent state
    expect(result.id.isNotEmpty, true);
    expect(result.state.toString().contains('sent'), true);
  });
}
