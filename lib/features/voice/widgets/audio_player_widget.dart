import 'dart:math';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fs_hub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fs_hub/core/utils/url_utils.dart';
import 'package:fs_hub/core/services/media_auth_service.dart';

/// Real audio player widget for voice notes
/// 
/// Features:
/// - Play/pause/stop controls
/// - Duration display
/// - Progress bar with seek
/// - Works with local files or URLs
class AudioPlayerWidget extends StatefulWidget {
  /// File path or URL to audio file
  final String source;
  
  /// Duration in milliseconds (optional - will be detected if not provided)
  final int? durationMs;
  
  /// Callback when user taps play (can be used to pause others)
  final VoidCallback? onPlay;
  
  /// Callback when playback completes
  final VoidCallback? onComplete;
  
  /// Show waveform visualization (if available)
  final List<double>? waveformData;
  
  /// Color of progress bar
  final Color progressColor;
  
  /// Disable playback (grayed out)
  final bool disabled;
  
  const AudioPlayerWidget({
    super.key,
    required this.source,
    this.durationMs,
    this.onPlay,
    this.onComplete,
    this.waveformData,
    this.progressColor = const Color(0xFFFFD700),
    this.disabled = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _durationSubscription;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('[VoiceAudioPlayer] initState called for source: ${widget.source}');
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    try {
      // Listen to position changes
      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() => _currentDuration = position);
        }
      });

      // Listen to player state changes
      _stateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          if (state.processingState == ProcessingState.completed && _isPlaying) {
            widget.onComplete?.call();
          }
        }
      });

      // Listen to duration changes
      _durationSubscription = _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _totalDuration = duration);
        }
      });

      
      
      // Set audio source
      if (widget.source.startsWith('blob:')) {
        // Web blob URL - use setUrl directly
        
        try {
          await _audioPlayer.setUrl(widget.source);
          
          if (mounted) {
            setState(() => _initialized = true);
          }
        } catch (e) {
          
          // Try alternative approach - reload and retry
          try {
            // Stop and restart the player
            await _audioPlayer.stop();
            await _audioPlayer.setUrl(widget.source);
            
            if (mounted) {
              setState(() => _initialized = true);
            }
          } catch (e2) {
            
            if (mounted) {
              setState(() {
                _error = 'Failed to load audio: $e';
                _initialized = true;
              });
            }
          }
        }
      } else if (widget.source.startsWith('http')) {
        // HTTP URL - use authentication
        final token = await AuthRemoteDatasource.getAccessToken();
        
        print('[VoiceAudioPlayer] Retrieved token: ${token != null ? "Token exists (${token.length} chars)" : "Token is null"}');
        print('[VoiceAudioPlayer] Source URL: ${widget.source}');
        
        if (kIsWeb) {
          final absolute = UrlUtils.ensureAbsoluteUrl(widget.source);
          final ticket = await MediaAuthService.ticketForMediaUrl(absolute);
          final authenticatedUrl = ticket != null
              ? UrlUtils.appendMediaTicket(absolute, ticket)
              : absolute;
          await _audioPlayer.setUrl(authenticatedUrl);
        } else {
          // On mobile platforms, try multiple authentication methods
          bool loadedSuccessfully = false;
          
          // Method 1: Try with Authorization header (preferred)
          if (!loadedSuccessfully && token != null && token.isNotEmpty) {
            try {
              final headers = <String, String>{
                'Authorization': 'Bearer $token',
                'User-Agent': 'FS-Hub-Android/1.0',
                'Accept': 'audio/*, */*;q=0.1',
              };
              print('[VoiceAudioPlayer] Mobile loading with Bearer token');
              await _audioPlayer.setUrl(widget.source, headers: headers);
              loadedSuccessfully = true;
              print('[VoiceAudioPlayer] Success with Bearer token');
            } catch (e) {
              print('[VoiceAudioPlayer] Bearer token failed: $e');
            }
          }
          
          if (!loadedSuccessfully) {
            try {
              final absolute = UrlUtils.ensureAbsoluteUrl(widget.source);
              final ticket = await MediaAuthService.ticketForMediaUrl(absolute);
              if (ticket != null) {
                final authenticatedUrl = UrlUtils.appendMediaTicket(absolute, ticket);
                await _audioPlayer.setUrl(authenticatedUrl);
                loadedSuccessfully = true;
              }
            } catch (_) {}
          }
          
          // Method 3: Try without token (for public URLs)
          if (!loadedSuccessfully) {
            try {
              print('[VoiceAudioPlayer] Mobile loading without token (public URL)');
              await _audioPlayer.setUrl(widget.source);
              loadedSuccessfully = true;
              print('[VoiceAudioPlayer] Success without token');
            } catch (e) {
              print('[VoiceAudioPlayer] Without token failed: $e');
            }
          }
          
          // If all methods failed, throw the last error
          if (!loadedSuccessfully) {
            throw Exception('All authentication methods failed for audio URL');
          }
        }
      } else {
        // Local file
        
        final file = io.File(widget.source);
        if (!kIsWeb && !await file.exists()) {
          throw Exception('Audio file does not exist: ${widget.source}');
        }
        if (!kIsWeb) {
          final fileSize = await file.length();
          
          if (fileSize == 0) {
            throw Exception('Audio file is empty (0 bytes): ${widget.source}');
          }
        }
        await _audioPlayer.setFilePath(widget.source);
      }

      
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _error = 'Failed to load audio: $e';
          _initialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (widget.disabled || _error != null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        widget.onPlay?.call();
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Playback error: $e');
      }
    }
  }

  Future<void> _seek(double fraction) async {
    final position = Duration(milliseconds: (_totalDuration.inMilliseconds * fraction).toInt());
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Seek error: $e');
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red[700], fontSize: 12),
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    if (!_initialized) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.disabled ? null : _togglePlayPause,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.disabled ? Colors.grey[300] : widget.progressColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.disabled ? Colors.grey[600] : Colors.black87,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.waveformData != null && widget.waveformData!.isNotEmpty)
                  _buildWaveformBar()
                else
                  _buildProgressBar(),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_currentDuration),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    const Text(' / ', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    Text(
                      _formatDuration(_totalDuration),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localPosition = box.globalToLocal(details.globalPosition);
        final fraction = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
        _seek(fraction);
      },
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
        child: FractionallySizedBox(
          widthFactor: _totalDuration.inMilliseconds > 0
              ? _currentDuration.inMilliseconds / _totalDuration.inMilliseconds
              : 0,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: widget.progressColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaveformBar() {
    final waveform = widget.waveformData!;
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localPosition = box.globalToLocal(details.globalPosition);
        final fraction = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
        _seek(fraction);
      },
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            // Waveform visualization
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: CustomPaint(
                painter: WaveformPainter(
                  waveform: waveform,
                  color: Colors.grey[600]!,
                  backgroundColor: Colors.grey[300]!,
                ),
                size: Size.infinite,
              ),
            ),
            // Progress overlay
            FractionallySizedBox(
              widthFactor: _totalDuration.inMilliseconds > 0
                  ? _currentDuration.inMilliseconds / _totalDuration.inMilliseconds
                  : 0,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.progressColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
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
    final barWidth = max(1.0, width / waveform.length);

    for (int i = 0; i < waveform.length; i++) {
      final amp = waveform[i].clamp(0.0, 1.0);
      final barHeight = height * amp;
      final left = i * barWidth;

      canvas.drawRect(
        Rect.fromLTWH(
          left,
          (height - barHeight) / 2,
          barWidth - 0.5,
          barHeight,
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
