import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../../../shared/models/message_model.dart';
import './message_queue.dart';
import '../../../core/services/rest_fallback_client.dart';
import '../../../core/services/websocket_client.dart';
import './message_store.dart';

class MessageService {
  final RESTFallbackClient rest;
  final WebSocketClient ws;
  final MessageQueue queue;
  final MessageStore store;
  final _uuid = Uuid();

  MessageService({required this.rest, required this.ws, required this.queue, required this.store});

  /// Send a text message. This will not render until server confirms via WS or REST response.
  Future<void> sendText(String conversationId, String senderId, String text) async {
    final tempId = _uuid.v4();
    final payload = {
      'id': tempId,
      'conversationId': conversationId,
      'senderId': senderId,
      'type': 'text',
      'content': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      // POST to /v1/conversations/{conversationId}/messages with senderId and content
      final res = await rest.post('/conversations/$conversationId/messages', {
        'senderId': senderId,
        'content': text,
        'type': 'text',
        'clientMessageId': tempId,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          final body = res.body;
          if (body != null && body.isNotEmpty) {
            final parsed = jsonDecode(body);
            final msg = parsed is Map && parsed['message'] != null ? parsed['message'] : parsed;
            if (msg is Map) {
              final canonical = Message.fromJson(Map<String, dynamic>.from(msg));
              store.replaceMessage(conversationId, tempId, canonical);
            }
          }
        } catch (_) {}
        return;
      } else {
        // enqueue for retry
        queue.enqueue(Message.fromJson(payload));
      }
    } catch (e) {
      // offline/failure: enqueue
      queue.enqueue(Message.fromJson(payload));
    }
  }

  /// Send message with attachments. Attachments are list of maps: {path, name, mime, size}
  Future<Stream<double>> sendWithAttachments(String conversationId, String senderId, String text, List<Map<String, dynamic>> attachments) async {
    final progressController = StreamController<double>();
    final tempId = _uuid.v4();

    // First: request signed URLs for each attachment
    final uploadInfos = <Map<String, dynamic>>[];
    try {
      for (final a in attachments) {
        final res = await rest.post('/v1/uploads/signed-url', {'filename': a['name'], 'mime': a['mime'], 'size': a['size']});
        if (res.statusCode == 200) {
          uploadInfos.add(Map<String, dynamic>.from(jsonDecode(res.body)));
        } else {
          throw Exception('signed-url failed');
        }
      }

      // perform uploads sequentially and emit progress
      int total = attachments.length;
      int done = 0;
      for (int i = 0; i < attachments.length; i++) {
        final a = attachments[i];
        final info = uploadInfos[i];
        final uploadUrl = (info['upload_url'] ?? info['uploadUrl']) as String;
        final file = File(a['path']);
        final bytes = await file.readAsBytes();
        // perform PUT
        final putRes = await http.put(Uri.parse(uploadUrl), headers: {'content-type': a['mime'] ?? 'application/octet-stream'}, body: bytes);
        if (putRes.statusCode != 200 && putRes.statusCode != 201) throw Exception('upload failed');
        done++;
        progressController.add(done / total * 0.9);

        // notify server upload complete for this file
        final notifyUploadId = info['upload_id'] ?? info['uploadId'];
        await rest.post('/v1/uploads/complete', {'upload_id': notifyUploadId, 'conversationId': conversationId, 'messageTempId': tempId, 'meta': a['meta'] ?? {}});
      }

      // final: send message record to persist references
      final msgPayload = {
        'id': tempId,
        'conversationId': conversationId,
        'senderId': senderId,
        'type': 'file',
        'content': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'meta': {'attachments': uploadInfos}
      };

      final res = await rest.post(
        '/conversations/$conversationId/messages',
        {
          'senderId': senderId,
          'content': text,
          'type': 'file',
          'meta': {'attachments': uploadInfos},
          'clientMessageId': tempId,
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          final body = res.body;
          if (body != null && body.isNotEmpty) {
            final parsed = jsonDecode(body);
            final msg = parsed is Map && parsed['message'] != null ? parsed['message'] : parsed;
            if (msg is Map) {
              final canonical = Message.fromJson(Map<String, dynamic>.from(msg));
              store.replaceMessage(conversationId, tempId, canonical);
            }
          }
        } catch (_) {}
        progressController.add(1.0);
        await progressController.close();
        return progressController.stream;
      } else {
        // enqueue message for later retry
        queue.enqueue(Message.fromJson(msgPayload));
        progressController.add(0.0);
        await progressController.close();
        return progressController.stream;
      }
    } catch (e) {
      // on any failure enqueue and close stream
      final fallbackMsg = {
        'id': tempId,
        'conversationId': conversationId,
        'senderId': senderId,
        'type': 'file',
        'content': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'meta': {'attachments': attachments}
      };
      queue.enqueue(Message.fromJson(fallbackMsg));
      progressController.add(0.0);
      await progressController.close();
      return progressController.stream;
    }
  }

  /// Emit typing state over WS
  void sendTyping(String conversationId, String userId, bool typing) {
    ws.send({'type': 'typing', 'payload': {'conversationId': conversationId, 'userId': userId, 'state': typing ? 'typing' : 'stopped'}});
  }
}
