import 'package:flutter/material.dart';
import 'package:fs_hub/services/real_audio_recorder.dart';
import 'package:fs_hub/widgets/audio_player_widget.dart';
import 'package:fs_hub/features/voice/services/waveform_generator.dart';

/// Callback type for voice recording completion
typedef VoiceRecordingCallback = void Function(String audioPath, int durationSeconds, String waveformData, dynamic bytes);

/// Voice recorder widget for composer bar integration
/// 
/// Features:
/// - Press and hold to record
/// - Visual feedback with waveform
/// - Duration display
/// - Cancel by sliding up or releasing early
/// - Preview before sending
class VoiceRecorder extends StatefulWidget {
  final VoiceRecordingCallback onRecordingComplete;
  final VoidCallback? onCancel;

  const VoiceRecorder({
    Key? key,
    required this.onRecordingComplete,
    this.onCancel,
  }) : super(key: key);

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  late RealAudioRecorder _recorder;
  bool _isRecording = false;
  bool _isPreview = false;
  double _recordingDuration = 0;
  RecordingResult? _recordingResult;
  bool _cancelMode = false;
  double _slideOffset = 0;

  @override
  void initState() {
    super.initState();
    _recorder = RealAudioRecorder();
    
    // Listen to duration updates
    _recorder.durationUpdates.listen((duration) {
      if (mounted) {
        setState(() {
          _recordingDuration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    print('VoiceRecorder: _startRecording called');
    try {
      await _recorder.requestPermission();
      await _recorder.start();
      setState(() {
        _isRecording = true;
        _cancelMode = false;
        _slideOffset = 0;
      });
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final result = await _recorder.stop();
      if (result != null) {
        setState(() {
          _recordingResult = result;
          _isRecording = false;
          _isPreview = true;
        });
      } else {
        setState(() {
          _isRecording = false;
        });
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
      widget.onCancel?.call();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isRecording) return;

    setState(() {
      _slideOffset = details.globalPosition.dy;
      // Enable cancel mode when sliding up by 50px or more
      _cancelMode = _slideOffset < -50;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isRecording) return;

    if (_cancelMode) {
      _cancelRecording();
    } else {
      _stopRecording();
    }

    setState(() {
      _slideOffset = 0;
      _cancelMode = false;
    });
  }

  void _sendRecording() {
    if (_recordingResult == null) return;

    // Generate waveform data
    String waveformData = '';
    try {
      waveformData = WaveformGenerator.generateWaveformFromM4A(_recordingResult!.fileBytes);
    } catch (e) {
      print('Error generating waveform: $e');
    }

    widget.onRecordingComplete(
      _recordingResult!.filePath,
      (_recordingResult!.durationMs / 1000).round(),
      waveformData,
      _recordingResult!.fileBytes,
    );

    setState(() {
      _isPreview = false;
      _recordingResult = null;
    });
  }

  void _discardRecording() {
    setState(() {
      _isPreview = false;
      _recordingResult = null;
      _recordingDuration = 0;
    });
    widget.onCancel?.call();
  }

  String _formatDuration(double seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds.toInt() % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreview && _recordingResult != null) {
      return _buildPreview();
    }

    if (_isRecording) {
      return _buildRecordingInterface();
    }

    return _buildIdleInterface();
  }

  Widget _buildIdleInterface() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Start Recording Button
              ElevatedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.mic, color: Colors.white),
                label: const Text('Start Recording', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[500],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to start recording',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingInterface() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Recording indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red[500],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Recording... ${_formatDuration(_recordingDuration)}',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stop and Cancel buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel Button
              OutlinedButton.icon(
                onPressed: _cancelRecording,
                icon: const Icon(Icons.close, color: Colors.grey),
                label: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              // Stop Recording Button
              ElevatedButton.icon(
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop, color: Colors.white),
                label: const Text('Stop', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[500],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_recordingResult == null) return const SizedBox();

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Duration badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDuration(_recordingResult!.durationMs / 1000),
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Audio player preview
            Expanded(
              child: AudioPlayerWidget(
                source: _recordingResult!.filePath,
                durationMs: _recordingResult!.durationMs,
                waveformData: WaveformGenerator.decodeWaveform(
                  WaveformGenerator.generateWaveformFromM4A(_recordingResult!.fileBytes)
                ),
                progressColor: Colors.blue[600]!,
              ),
            ),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _discardRecording,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Discard'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[600],
                  ),
                ),
                TextButton.icon(
                  onPressed: _sendRecording,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Send'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
