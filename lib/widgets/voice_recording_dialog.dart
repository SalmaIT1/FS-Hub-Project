import 'package:flutter/material.dart';
import 'package:fs_hub/services/real_audio_recorder.dart';
import 'package:fs_hub/widgets/audio_player_widget.dart';
import 'package:fs_hub/features/voice/services/waveform_generator.dart';

/// Dialog shown after recording completes
/// 
/// Allows user to:
/// - Preview the recording
/// - Accept and send
/// - Discard and record again
class VoiceRecordingPreviewDialog extends StatefulWidget {
  final RecordingResult recording;
  final VoidCallback onSend;
  final VoidCallback onDiscard;
  
  const VoiceRecordingPreviewDialog({
    Key? key,
    required this.recording,
    required this.onSend,
    required this.onDiscard,
  }) : super(key: key);

  @override
  State<VoiceRecordingPreviewDialog> createState() => _VoiceRecordingPreviewDialogState();
}

class _VoiceRecordingPreviewDialogState extends State<VoiceRecordingPreviewDialog> {
  late final List<double>? _waveformData;
  String? _loadError;
  
  @override
  void initState() {
    super.initState();

    
    try {
      if (widget.recording.fileBytes.isEmpty) {
        _loadError = 'Audio file is empty (0 bytes)';
        _waveformData = null;
        return;
      }
      
      final waveform = WaveformGenerator.generateWaveformFromM4A(widget.recording.fileBytes);
      _waveformData = WaveformGenerator.decodeWaveform(waveform);

    } catch (e) {
      _waveformData = null;

    }
  }

  String _formatDuration(int ms) {
    final seconds = ms ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
    return '0:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              'Voice Message',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            
            // Show error if loading failed
            if (_loadError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _loadError!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            
            // Duration badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(widget.recording.durationMs),
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Player widget
            Theme(
              data: Theme.of(context).copyWith(
                sliderTheme: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
              ),
              child: AudioPlayerWidget(
                source: widget.recording.filePath,
                durationMs: widget.recording.durationMs,
                waveformData: _waveformData,
                progressColor: const Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Discard button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDiscard();
                  },
                  icon: const Icon(Icons.close, size: 20),
                  label: const Text('Discard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[400]!),
                  ),
                ),
                
                // Send button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onSend();
                  },
                  icon: const Icon(Icons.send, size: 20),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black87,
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

/// Recording in-progress indicator overlay
class RecordingIndicator extends StatefulWidget {
  final Stream<double> durationStream;
  final Stream<bool> isRecordingStream;
  final bool cancelMode;
  
  const RecordingIndicator({
    Key? key,
    required this.durationStream,
    required this.isRecordingStream,
    this.cancelMode = false,
  }) : super(key: key);

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator> {
  double _duration = 0;
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Microphone icon with pulsing animation
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red[500]!.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    Icons.mic,
                    size: 40,
                    color: Colors.red[500],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Duration display
              StreamBuilder<double>(
                stream: widget.durationStream,
                initialData: 0,
                builder: (context, snapshot) {
                  _duration = snapshot.data ?? 0;
                  final minutes = _duration.toInt() ~/ 60;
                  final seconds = (_duration.toInt() % 60);
                  final millis = ((_duration - _duration.toInt()) * 100).toInt();
                  
                  return Column(
                    children: [
                      Text(
                        '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.cancelMode ? '←  Slide to cancel' : 'Recording...',
                        style: TextStyle(
                          color: widget.cancelMode ? Colors.orange : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Recording indicator bar
              Container(
                height: 3,
                width: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white24,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.red[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
