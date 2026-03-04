import 'package:flutter/material.dart';
import 'package:fs_hub/features/chat/presentation/pages/conversation_list_page.dart' as chat_ui;
import 'package:fs_hub/features/chat/presentation/pages/chat_thread_page.dart' as chat_ui;
import 'package:fs_hub/features/chat/domain/entities/chat_entities.dart';

class ChatRouter {
  static PageRouteBuilder _makeRoute(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutQuart;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  static Route buildHome() {
    return _makeRoute(const chat_ui.ConversationListPage());
  }

  static Route thread(String conversationId, {ConversationEntity? conversation}) {
    return _makeRoute(chat_ui.ChatThreadPage(
      conversationId: conversationId,
      conversation: conversation,
    ));
  }
}
