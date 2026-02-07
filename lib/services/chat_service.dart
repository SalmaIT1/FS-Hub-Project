import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  static const String baseUrl = 'http://localhost:8080/api';
  static bool _isConnected = false;

  static Future<void> connect(String userId) async {
    // Simulate connection to chat service
    _isConnected = true;
    print('ChatService: Connected user $userId');
  }

  static void startTyping(String conversationId) {
    if (!_isConnected) return;
    print('ChatService: Started typing in conversation $conversationId');
    // In a real implementation, this would send a WebSocket event
  }

  static void stopTyping(String conversationId) {
    if (!_isConnected) return;
    print('ChatService: Stopped typing in conversation $conversationId');
    // In a real implementation, this would send a WebSocket event
  }

  static Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String content,
    required String type,
    required String senderId,
  }) async {
    if (!_isConnected) return null;

    try {
      // In a real implementation, this would send via WebSocket or HTTP
      print('ChatService: Sending message - Content: $content, Type: $type');
      
      // Simulate message response
      return {
        'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
        'conversationId': conversationId,
        'content': content,
        'type': type,
        'senderId': senderId,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sent'
      };
    } catch (e) {
      print('ChatService: Error sending message - $e');
      return null;
    }
  }

  static Future<String?> uploadFile(File file) async {
    if (!_isConnected) return null;

    try {
      // Simulate file upload
      print('ChatService: Uploading file ${file.path}');
      
      // In a real implementation, this would upload via HTTP multipart
      // For now, return a simulated file ID
      return 'file_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('ChatService: Error uploading file - $e');
      return null;
    }
  }

  static Stream<Map<String, dynamic>> get events {
    // Return a dummy stream for demonstration
    return Stream.fromIterable([
      {
        'type': 'connected',
        'data': {'message': 'Chat service initialized'}
      }
    ]);
  }
}

class VoiceRecorder {
  static bool _isRecording = false;
  static DateTime? _startTime;

  static Future<bool> startRecording() async {
    // Simulate starting voice recording
    _isRecording = true;
    _startTime = DateTime.now();
    print('VoiceRecorder: Started recording');
    return true;
  }

  static Future<Map<String, dynamic>?> stopRecording() async {
    if (!_isRecording) return null;

    _isRecording = false;
    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime!).inSeconds;
    
    print('VoiceRecorder: Stopped recording, duration: ${duration}s');
    
    // Simulate voice recording result
    return {
      'duration': '${duration}s',
      'fileId': 'voice_${DateTime.now().millisecondsSinceEpoch}',
      'waveform': [0.1, 0.3, 0.7, 0.5, 0.9, 0.4, 0.6, 0.2]
    };
  }

  static void cancelRecording() {
    if (_isRecording) {
      _isRecording = false;
      print('VoiceRecorder: Cancelled recording');
    }
  }

  static bool get isRecording => _isRecording;
}