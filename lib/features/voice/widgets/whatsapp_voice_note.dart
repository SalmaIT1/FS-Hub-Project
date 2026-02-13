import 'package:flutter/material.dart';
import '../widgets/audio_player_widget.dart';
import '../services/waveform_generator.dart';
import '../../chat/domain/chat_entities.dart';

/// WhatsApp-style voice note component
class WhatsAppVoiceNote extends StatefulWidget {
  final VoiceNoteEntity voice;
  final bool isSentByMe;

  const WhatsAppVoiceNote({
    Key? key,
    required this.voice,
    this.isSentByMe = false,
  }) : super(key: key);

  @override
  State<WhatsAppVoiceNote> createState() => _WhatsAppVoiceNoteState();
}

class _WhatsAppVoiceNoteState extends State<WhatsAppVoiceNote> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isSentByMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSentByMe ? Colors.transparent : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.isSentByMe ? const Color(0xFF128C7E) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // Waveform visualization
              Expanded(
                child: Container(
                  height: 30,
                  child: widget.voice.waveformData.isNotEmpty
                      ? _buildWaveform()
                      : _buildPlaceholderWaveform(),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Duration
              Text(
                _formatDuration(widget.voice.durationMs),
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isSentByMe ? const Color(0xFF128C7E) : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    try {
      final waveformData = WaveformGenerator.decodeWaveform(widget.voice.waveformData);
      return CustomPaint(
        painter: WhatsAppWaveformPainter(
          waveform: waveformData,
          color: widget.isSentByMe ? const Color(0xFF128C7E) : Colors.grey,
          isPlaying: _isPlaying,
        ),
        size: Size.infinite,
      );
    } catch (e) {
      print('Error rendering WhatsApp waveform: $e');
      return _buildPlaceholderWaveform();
    }
  }

  Widget _buildPlaceholderWaveform() {
    return Container(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(25, (index) {
          final height = 4.0 + (index % 5) * 3.0;
          return Container(
            width: 2,
            height: height,
            decoration: BoxDecoration(
              color: widget.isSentByMe ? const Color(0xFF128C7E) : Colors.grey[500],
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
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
}

/// WhatsApp-style waveform painter with animated playback
class WhatsAppWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;
  final bool isPlaying;

  WhatsAppWaveformPainter({
    required this.waveform,
    required this.color,
    this.isPlaying = false,
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
      final barHeight = height * amp * 0.7; // Scale to 70% of height
      final left = (i / step) * totalBarWidth;

      // Make bars slightly transparent when not playing
      final opacity = isPlaying ? 1.0 : 0.6;
      
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
        Paint()
          ..color = color.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(WhatsAppWaveformPainter oldDelegate) {
    return oldDelegate.waveform != waveform ||
        oldDelegate.color != color ||
        oldDelegate.isPlaying != isPlaying;
  }
}
