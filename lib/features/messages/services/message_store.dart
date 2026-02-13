import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../shared/models/message_model.dart';

class MessageStore extends ChangeNotifier {
  final Map<String, List<Message>> _conversations = {};
  final _updated = StreamController<Message>.broadcast();
  Stream<Message> get updates => _updated.stream;

  List<Message> messagesFor(String conversationId) {
    return List.unmodifiable(_conversations[conversationId] ?? []);
  }

  void addMessage(Message m) {
    final list = _conversations.putIfAbsent(m.conversationId, () => []);
    // de-dup by id
    if (!list.any((e) => e.id == m.id)) {
      list.add(m);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _updated.add(m);
      notifyListeners();
    }
  }

  void replaceMessage(String conversationId, String tempId, Message canonical) {
    final list = _conversations[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == tempId);
    if (idx >= 0) {
      list[idx] = canonical;
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    }
  }

  void markRead(String conversationId, String messageId) {
    final list = _conversations[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx >= 0) {
      final m = list[idx];
      list[idx] = Message(
        id: m.id,
        conversationId: m.conversationId,
        senderId: m.senderId,
        type: m.type,
        content: m.content,
        timestamp: m.timestamp,
        read: true,
        meta: m.meta,
      );
      notifyListeners();
    }
  }

  void clearConversation(String conversationId) {
    _conversations.remove(conversationId);
    notifyListeners();
  }

  void dispose() {
    _updated.close();
    super.dispose();
  }
}
