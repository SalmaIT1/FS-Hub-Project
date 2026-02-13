import 'package:flutter/material.dart';
import 'package:fs_hub/widgets/audio_player_widget.dart';
import 'package:fs_hub/features/voice/services/waveform_generator.dart';
import '../domain/chat_entities.dart';

/// Adaptive voice note component that works across platforms
class AdaptiveVoiceNote extends StatefulWidget {
  final VoiceNoteEntity voice;
  final bool isSentByMe;
  final Color? bubbleColor;

  const AdaptiveVoiceNote({
    Key? key,
    required this.voice,
    this.isSentByMe = false,
    this.bubbleColor,
  }) : super(key: key);

  @override
  State<AdaptiveVoiceNote> createState() => _AdaptiveVoiceNoteState();
}

class _AdaptiveVoiceNoteState extends State<AdaptiveVoiceNote> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    // Use AudioPlayerWidget for consistent audio playback with compact layout
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
      child: AudioPlayerWidget(
        source: widget.voice.uploadUrl, // Use backend URL for playback
        durationMs: widget.voice.durationMs,
        waveformData: widget.voice.waveformData.isNotEmpty 
          ? WaveformGenerator.decodeWaveform(widget.voice.waveformData)
          : null,
        onPlay: () {
          setState(() {
            _isPlaying = true;
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
          });
        },
      ),
    );
  }
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;
  final Color backgroundColor;

  WaveformPainter({
    required this.waveform,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final height = size.height;
    final width = size.width;
    final barWidth = 2.0;
    final spacing = 1.0;
    final totalBarWidth = barWidth + spacing;
    final maxBars = (width / totalBarWidth).floor();

    // Downsample if we have too many points
    final step = (waveform.length / maxBars).ceil().clamp(1, waveform.length);

    for (int i = 0; i < waveform.length && (i * totalBarWidth) < width; i += step) {
      final amp = waveform[i].clamp(0.0, 1.0);
      final barHeight = height * amp * 0.8; // Scale to 80% of height
      final left = (i / step) * totalBarWidth;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left,
            (height - barHeight) / 2,
            barWidth,
            barHeight,
          ),
          const Radius.circular(1),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveform != waveform ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
