import 'dart:async';
import 'dart:convert';
import '../models/message.dart';
import 'rest_fallback_client.dart';
import 'message_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum QueueState { pending, sending, failed, sent }

class QueueItem {
  final Message message;
  QueueState state;
  int attempts;

  QueueItem(this.message) : state = QueueState.pending, attempts = 0;
}

class MessageQueue {
  final List<QueueItem> _queue = [];
  final RESTFallbackClient rest;
  final MessageStore? store;

  MessageQueue({required this.rest, this.store});

  static const _storageKey = 'chat_queue_v1';

  Future<void> loadFromDisk() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_storageKey);
    if (raw == null) return;
    try {
      final List<dynamic> arr = jsonDecode(raw);
      _queue.clear();
      for (final e in arr) {
        final m = Message.fromJson(Map<String, dynamic>.from(e['message']));
        final item = QueueItem(m);
        item.attempts = e['attempts'] ?? 0;
        item.state = QueueState.values.firstWhere((s) => s.toString() == e['state'], orElse: () => QueueState.pending);
        _queue.add(item);
      }
    } catch (_) {}
  }

  Future<void> persistToDisk() async {
    final sp = await SharedPreferences.getInstance();
    final arr = _queue.map((q) => {'message': q.message.toJson(), 'attempts': q.attempts, 'state': q.state.toString()}).toList();
    await sp.setString(_storageKey, jsonEncode(arr));
  }

  void enqueue(Message m) {
    if (_queue.any((q) => q.message.id == m.id)) return;
    _queue.add(QueueItem(m));
    persistToDisk();
    _processNext();
  }

  bool _running = false;

  Future<void> _processNext() async {
    if (_running) return;
    _running = true;
    while (_queue.isNotEmpty) {
      final item = _queue.first;
      try {
        item.state = QueueState.sending;
        item.attempts++;
        // POST to /conversations/{conversationId}/messages with senderId and content
        final msgJson = item.message.toJson();
        final res = await rest.post(
          '/conversations/${msgJson['conversationId']}/messages',
          {
            'senderId': msgJson['senderId'],
            'content': msgJson['content'],
            'type': msgJson['type'] ?? 'text',
            'clientMessageId': msgJson['id'],
          },
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          try {
            final body = res.body;
            if (body != null && body.isNotEmpty) {
              final parsed = jsonDecode(body);
              final msg = parsed is Map && parsed['message'] != null ? parsed['message'] : parsed;
              if (msg is Map && store != null) {
                final canonical = Message.fromJson(Map<String, dynamic>.from(msg));
                store!.replaceMessage(msg['conversationId']?.toString() ?? '', item.message.id, canonical);
              }
            }
          } catch (_) {}
          item.state = QueueState.sent;
          _queue.removeAt(0);
          await persistToDisk();
        } else {
          if (item.attempts >= 3) {
            item.state = QueueState.failed;
            _queue.removeAt(0);
            await persistToDisk();
          } else {
            await Future.delayed(Duration(seconds: 2 * item.attempts));
          }
        }
      } catch (_) {
        if (item.attempts >= 3) {
          item.state = QueueState.failed;
          _queue.removeAt(0);
          await persistToDisk();
        } else {
          await Future.delayed(Duration(seconds: 2 * item.attempts));
        }
      }
    }
    _running = false;
  }
}
