import 'package:flutter/material.dart';
import 'package:fs_hub/chat/ui/conversation_list_page.dart' as new_chat;
import 'package:fs_hub/chat/ui/chat_thread_page.dart' as new_chat;
import 'package:fs_hub/chat/domain/chat_entities.dart';

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
    return _makeRoute(const new_chat.ConversationListPage());
  }

  static Route thread(String conversationId, {ConversationEntity? conversation}) {
    return _makeRoute(new_chat.ChatThreadPage(
      conversationId: conversationId,
      conversation: conversation,
    ));
  }
}
