import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:html' as html;

class RecordingResult {
  final String filePath;
  final List<int> fileBytes;
  final int durationMs;
  final String filename;

  RecordingResult({
    required this.filePath,
    required this.fileBytes,
    required this.durationMs,
    required this.filename,
  });
}

/// Real audio recorder using mic input
class RealAudioRecorder {
  final _recorder = AudioRecorder();
  RecordingState _state = RecordingState.initial;
  Timer? _durationTimer;
  int _durationMs = 0;
  final _durationController = StreamController<double>.broadcast();

  Stream<double> get durationUpdates => _durationController.stream;
  RecordingState get state => _state;

  Future<void> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      print('[RealAudioRecorder.requestPermission] Status: $status');
      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }
    } catch (e) {
      print('[RealAudioRecorder.requestPermission] Error: $e');
      rethrow;
    }
  }

  Future<void> start() async {
    try {
      print('[RealAudioRecorder.start] Checking microphone permission...');
      final hasPerm = await Permission.microphone.status;
      print('[RealAudioRecorder.start] Permission status: $hasPerm');
      if (!hasPerm.isGranted) {
        throw Exception('Microphone permission is required');
      }

      
      String filePath;
      String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      if (kIsWeb) {
        // On web, use a simple filename for the plugin
        filePath = fileName;
        print('[RealAudioRecorder.start] Web recording - using filename: $filePath');
      } else {
        final tempDir = await getTemporaryDirectory();
        filePath = io.File('${tempDir.path}/$fileName').path;
      }

      print('[RealAudioRecorder.start] Recording to: $filePath');

      await _recorder.start(
        path: filePath,
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
      );

      _state = RecordingState.recording;
      _durationMs = 0;
      _startDurationTimer();

      print('[RealAudioRecorder.start] Recording started');
    } catch (e) {
      print('[RealAudioRecorder.start] Error: $e');
      _state = RecordingState.initial;
      rethrow;
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _durationMs += 100;
      _durationController.add(_durationMs / 1000.0);
    });
  }

  Future<RecordingResult?> stop() async {
    try {
      _durationTimer?.cancel();
      print('[RealAudioRecorder.stop] Stopping recorder...');

      final path = await _recorder.stop();
      if (path == null) {
        print('[RealAudioRecorder.stop] Recorder returned null path');
        _state = RecordingState.initial;
        return null;
      }

      print('[RealAudioRecorder.stop] Recorder stopped. Path: $path');

      // Wait for AAC container finalization
      await Future.delayed(const Duration(milliseconds: 200));

      final file = kIsWeb ? null : io.File(path);
      
      if (!kIsWeb) {
        print('[RealAudioRecorder.stop] PATH: $path');
        print('[RealAudioRecorder.stop] EXISTS: ${await file!.exists()}');
        
        if (!await file!.exists()) {
          print('[RealAudioRecorder.stop] Recorded file does not exist');
          _state = RecordingState.initial;
          return null;
        }

        final size = await file.length();
        print('[RealAudioRecorder.stop] SIZE: $size bytes');

        if (size == 0) {
          print('[RealAudioRecorder.stop] Recorded file is empty (0 bytes)');
          _state = RecordingState.initial;
          return null;
        }

        // Read file bytes
        print('[RealAudioRecorder.stop] Reading file bytes...');
        final fileBytes = await file.readAsBytes();
        print('[RealAudioRecorder.stop] Read ${fileBytes.length} bytes');

        final filename = path.split('/').last;

        _state = RecordingState.initial;
        print('[RealAudioRecorder.stop] Recording complete: $_durationMs ms');

        return RecordingResult(
          filePath: path,
          fileBytes: fileBytes,
          durationMs: _durationMs,
          filename: filename,
        );
      } else {
        // Web: return blob URL directly - let upload handle it
        final filename = path.split('/').last;
        _state = RecordingState.initial;
        print('[RealAudioRecorder.stop] Recording complete (web): $_durationMs ms');
        print('[RealAudioRecorder.stop] BLOB URL: $path');

        // For web, return empty bytes - upload will fetch blob URL
        return RecordingResult(
          filePath: path, // This is the blob URL
          fileBytes: [], // Empty - upload service will handle blob fetching
          durationMs: _durationMs,
          filename: filename,
        );
      }
    } catch (e) {
      print('[RealAudioRecorder.stop] Error: $e');
      _state = RecordingState.initial;
      return null;
    }
  }

  Future<void> cancel() async {
    try {
      _durationTimer?.cancel();
      print('[RealAudioRecorder.cancel] Cancelling...');

      final path = await _recorder.stop();
      if (path != null && !kIsWeb) {
        final file = io.File(path);
        if (await file.exists()) {
          await file.delete();
          print('[RealAudioRecorder.cancel] File deleted');
        }
      }

      _state = RecordingState.initial;
      _durationMs = 0;
      print('[RealAudioRecorder.cancel] Cancelled');
    } catch (e) {
      print('[RealAudioRecorder.cancel] Error: $e');
    }
  }

  void dispose() {
    _durationTimer?.cancel();
    _durationController.close();
    _recorder.dispose();
  }

  String get duration => '${_durationMs ~/ 1000}';

  Future<List<int>> _fetchBlobAsBytes(String blobUrl) async {
    try {
      final response = await html.HttpRequest.request(
        blobUrl,
        method: 'GET',
        responseType: 'arraybuffer',
      );
      
      if (response.status == 200) {
        final arrayBuffer = response.response as dynamic;
        try {
          return Uint8List.view(arrayBuffer).toList();
        } catch (e) {
          print('[RealAudioRecorder._fetchBlobAsBytes] Error converting array buffer: $e');
          return [];
        }
      }
      return [];
    } catch (e) {
      print('[RealAudioRecorder._fetchBlobAsBytes] Error: $e');
      return [];
    }
  }
}

enum RecordingState { initial, recording, stopped }
