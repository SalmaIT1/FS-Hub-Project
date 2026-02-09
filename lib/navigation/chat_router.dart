import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/chat/data/chat_rest_client.dart';
import 'package:fs_hub/chat/data/chat_socket_client.dart';
import 'package:fs_hub/chat/data/upload_service.dart';
import 'package:fs_hub/chat/data/chat_repository.dart';
import 'package:fs_hub/chat/state/chat_controller.dart';
import 'package:fs_hub/chat/ui/conversation_list_page.dart' as new_chat;
import 'package:fs_hub/chat/ui/chat_thread_page.dart' as new_chat;
import '../services/auth_service.dart';

class ChatRouter {
  static PageRouteBuilder _makeRoute(Widget child) {
    return PageRouteBuilder(pageBuilder: (_, __, ___) => child);
  }

  static Route buildHome() {
    // Initialize chat stack synchronously and provide to child
    const apiBase = 'http://localhost:8080';
    const wsBase = 'ws://localhost:8080/ws';

    Future<String> tokenProvider() async {
      try {
        final token = await AuthService.getAccessToken();
        print('[TOKEN-PROVIDER] buildHome: token=${token != null ? "present" : "NULL"}');
        if (token == null) {
          print('[TOKEN-PROVIDER] WARNING: getAccessToken returned null!');
        }
        return token ?? '';
      } catch (e) {
        print('[TOKEN-PROVIDER] ERROR in buildHome: $e');
        rethrow;
      }
    }

    final rest = ChatRestClient(baseUrl: apiBase, tokenProvider: tokenProvider);
    final socket = ChatSocketClient(wsUrl: wsBase, tokenProvider: tokenProvider);
    final uploads = UploadService(baseUrl: apiBase, tokenProvider: tokenProvider);
    final repo = ChatRepository(rest: rest, socket: socket, uploads: uploads);
    final controller = ChatController(repository: repo);

    final provider = MultiProvider(
      providers: [
        Provider<ChatRestClient>(create: (_) => rest),
        Provider<ChatSocketClient>(create: (_) => socket),
        Provider<UploadService>(create: (_) => uploads),
        Provider<ChatRepository>(create: (_) => repo),
        ChangeNotifierProvider<ChatController>(create: (_) => controller),
      ],
      child: const new_chat.ConversationListPage(),
    );

    return _makeRoute(provider);
  }

  static Route thread(String conversationId) {
    const apiBase = 'http://localhost:8080';
    const wsBase = 'ws://localhost:8080/ws';

    Future<String> tokenProvider() async => (await AuthService.getAccessToken()) ?? '';

    final rest = ChatRestClient(baseUrl: apiBase, tokenProvider: tokenProvider);
    final socket = ChatSocketClient(wsUrl: wsBase, tokenProvider: tokenProvider);
    final uploads = UploadService(baseUrl: apiBase, tokenProvider: tokenProvider);
    final repo = ChatRepository(rest: rest, socket: socket, uploads: uploads);
    final controller = ChatController(repository: repo);

    final provider = MultiProvider(
      providers: [
        Provider<ChatRestClient>(create: (_) => rest),
        Provider<ChatSocketClient>(create: (_) => socket),
        Provider<UploadService>(create: (_) => uploads),
        Provider<ChatRepository>(create: (_) => repo),
        ChangeNotifierProvider<ChatController>(create: (_) => controller),
      ],
      child: new_chat.ChatThreadPage(conversationId: conversationId),
    );

    return _makeRoute(provider);
  }
}
