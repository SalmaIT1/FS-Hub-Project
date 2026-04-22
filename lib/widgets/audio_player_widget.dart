import 'dart:math';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:fs_hub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fs_hub/core/utils/url_utils.dart';

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
  AudioPlayer? _audioPlayer;
  ap.AudioPlayer? _fallbackPlayer;
  bool _useFallback = false;
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
    print('[AudioPlayerWidget] initState called for source: ${widget.source}');
    _initializeAudioPlayer();
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      final absoluteSource = UrlUtils.ensureAbsoluteUrl(widget.source);
      print('[AudioPlayerWidget] _initializeAudioPlayer starting for source: $absoluteSource');
      if (mounted) {
        setState(() {
          _initialized = false;
          _error = null;
          _useFallback = false;
        });
      }

      // Special handling for native: If it's a local file, wait a bit for any file locks 
      // (e.g. from the recorder) to be released.
      if (!kIsWeb && !absoluteSource.startsWith('http') && !absoluteSource.startsWith('blob:') && !absoluteSource.startsWith('data:')) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Try just_audio first
      _audioPlayer = AudioPlayer();
      
      // We wrap the setup in a longer timeout for Windows engine startup
      await _setupAudioPlayer(absoluteSource).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Primary player setup timed out'),
      );
      
    } catch (e) {
      print('[AudioPlayerWidget] Primary player failed, trying fallback: $e');
      
      // Clean up failed player
      try {
        await _audioPlayer?.dispose();
      } catch (_) {}
      _audioPlayer = null;
      _useFallback = true;
      
      try {
        if (!mounted) return;
        _fallbackPlayer = ap.AudioPlayer();
        final absoluteSource = UrlUtils.ensureAbsoluteUrl(widget.source);
        await _setupFallbackPlayer(absoluteSource).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Fallback player setup timed out'),
        );
      } catch (e2) {
        print('[AudioPlayerWidget] Both players failed: $e2');
        if (mounted) {
          setState(() {
            _error = e2 is TimeoutException 
              ? 'Loading timed out. Please check your connection or file.'
              : 'Failed to load audio: $e2';
            _initialized = true;
          });
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _initialized = false;
      _error = null;
      _initializeAudioPlayer();
    }
  }

  Future<void> _setupFallbackPlayer(String source) async {
    if (_fallbackPlayer == null) return;
 
    // Set up source for audioplayers with Android-specific handling
    try {
      if (source.startsWith('http') || source.startsWith('blob:') || source.startsWith('data:')) {
        final token = await AuthRemoteDatasource.getAccessToken();
        
        print('[AudioPlayerWidget] Fallback - Retrieved token: ${token != null ? "Token exists" : "Token is null"}');
        print('[AudioPlayerWidget] Fallback - Source URL: $source');
        
        // Try multiple authentication methods in order of preference
        bool loadedSuccessfully = false;
        
        // Method 1: Try with token as query parameter (most compatible)
        if (!loadedSuccessfully && token != null && token.isNotEmpty) {
          try {
            final authenticatedUrl = UrlUtils.appendToken(source, token);
            print('[AudioPlayerWidget] Fallback - Trying token as query parameter');
            await _fallbackPlayer!.setSource(ap.UrlSource(authenticatedUrl));
            loadedSuccessfully = true;
            print('[AudioPlayerWidget] Fallback - Success with query parameter');
          } catch (e) {
            print('[AudioPlayerWidget] Fallback - Query parameter failed: $e');
          }
        }
        
        // Method 2: Try without token (for public URLs)
        if (!loadedSuccessfully) {
          try {
            print('[AudioPlayerWidget] Fallback - Trying without token (public URL)');
            await _fallbackPlayer!.setSource(ap.UrlSource(source));
            loadedSuccessfully = true;
            print('[AudioPlayerWidget] Fallback - Success without token');
          } catch (e) {
            print('[AudioPlayerWidget] Fallback - Without token failed: $e');
          }
        }
        
        // If all methods failed, throw the last error
        if (!loadedSuccessfully) {
          throw Exception('All authentication methods failed for audio URL');
        }
      } else {
        final file = io.File(source);
        if (!kIsWeb && !await file.exists()) {
          throw Exception('Audio file does not exist: $source');
        }
        
        // Android-specific: Check file and handle device file access
        if (!kIsWeb && io.Platform.isAndroid) {
          final fileSize = await file.length();
          if (fileSize == 0) {
            throw Exception('Audio file is empty: $source');
          }
          
          // Wait for file system operations on Android
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
        await _fallbackPlayer!.setSourceDeviceFile(source);
      }

      // Mark as initialized IMMEDIATELY once source is set
      // Metadata like duration can load in background
      if (mounted) {
        setState(() => _initialized = true);
      }

      // Try to get duration in background with Android-specific timeout
      _fallbackPlayer!.getDuration().timeout(
        io.Platform.isAndroid ? const Duration(seconds: 10) : const Duration(seconds: 5),
        onTimeout: () => null,
      ).then((duration) {
        if (duration != null && mounted) {
          setState(() {
            _totalDuration = Duration(milliseconds: duration.inMilliseconds);
          });
        }
      }).catchError((e) {
        print('[AudioPlayerWidget] Background duration fetch error: $e');
      });

      // Listen to position changes
      _fallbackPlayer!.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() => _currentDuration = position);
        }
      });

      // Listen to player state changes
      _fallbackPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state == ap.PlayerState.playing);
          if (state == ap.PlayerState.completed) {
            widget.onComplete?.call();
          }
        }
      });
    } catch (e) {
      // Android-specific error handling for fallback player
      String errorMessage = 'Failed to load audio with fallback player';
      
      if (io.Platform.isAndroid) {
        if (e.toString().contains('Response code: 401') || e.toString().contains('401')) {
          errorMessage = 'Authentication failed. Please log out and log back in to refresh your session.';
        } else if (e.toString().contains('Source error') || e.toString().contains('failed to load')) {
          errorMessage = 'Android audio playback error. Try restarting the app or checking file permissions.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Storage permission required for audio playback on Android.';
        } else {
          errorMessage = 'Android audio error: $e';
        }
      } else {
        if (e.toString().contains('Response code: 401') || e.toString().contains('401')) {
          errorMessage = 'Authentication failed. Please check your login status.';
        } else {
          errorMessage = 'Fallback player error: $e';
        }
      }
      
      print('[AudioPlayerWidget] Fallback error details: $e');
      throw Exception(errorMessage);
    }
  }

  Future<void> _setupAudioPlayer(String source) async {
    if (_audioPlayer == null) return;
    
    // Clean up previous subscriptions if re-initializing
    await _positionSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _durationSubscription?.cancel();
 
    // Listen to position changes
    _positionSubscription = _audioPlayer!.positionStream.listen((position) {
      if (mounted) {
        setState(() => _currentDuration = position);
      }
    });
 
    // Listen to player state changes
    _stateSubscription = _audioPlayer!.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed && _isPlaying) {
          widget.onComplete?.call();
        }
      }
    });
 
    // Listen to duration changes
    _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() => _totalDuration = duration);
      }
    });
 
    // Set audio source with Android-specific handling
    try {
      if (source.startsWith('blob:')) {
        await _audioPlayer!.setUrl(source);
      } else if (source.startsWith('http')) {
        final token = await AuthRemoteDatasource.getAccessToken();
        
        print('[AudioPlayerWidget] Primary - Retrieved token: ${token != null ? "Token exists" : "Token is null"}');
        print('[AudioPlayerWidget] Primary - Source URL: $source');
        
        if (kIsWeb) {
          // On web, use token as query parameter
          final authenticatedUrl = UrlUtils.appendToken(source, token);
          print('[AudioPlayerWidget] Web loading with token URL');
          await _audioPlayer!.setUrl(authenticatedUrl);
        } else {
          // On mobile platforms, try multiple authentication methods
          bool loadedSuccessfully = false;
          
          // Method 1: Try with Authorization header (preferred)
          if (!loadedSuccessfully && token != null && token.isNotEmpty) {
            try {
              final headers = <String, String>{
                'Authorization': 'Bearer $token',
                'User-Agent': 'FS-Hub-Client/1.0',
                'Accept': 'audio/*, */*;q=0.1',
              };
              print('[AudioPlayerWidget] Mobile loading with Bearer token');
              await _audioPlayer!.setUrl(source, headers: headers);
              loadedSuccessfully = true;
              print('[AudioPlayerWidget] Success with Bearer token');
            } catch (e) {
              print('[AudioPlayerWidget] Bearer token failed: $e');
            }
          }
          
          // Method 2: Try with token as query parameter (fallback)
          if (!loadedSuccessfully) {
            try {
              final authenticatedUrl = UrlUtils.appendToken(source, token);
              print('[AudioPlayerWidget] Mobile loading with token as query parameter');
              await _audioPlayer!.setUrl(authenticatedUrl);
              loadedSuccessfully = true;
              print('[AudioPlayerWidget] Success with query parameter');
            } catch (e) {
              print('[AudioPlayerWidget] Query parameter failed: $e');
            }
          }
          
          // Method 3: Try without token (for public URLs)
          if (!loadedSuccessfully) {
            try {
              print('[AudioPlayerWidget] Mobile loading without token (public URL)');
              await _audioPlayer!.setUrl(source);
              loadedSuccessfully = true;
              print('[AudioPlayerWidget] Success without token');
            } catch (e) {
              print('[AudioPlayerWidget] Without token failed: $e');
            }
          }
          
          // If all methods failed, throw the last error
          if (!loadedSuccessfully) {
            throw Exception('All authentication methods failed for audio URL');
          }
        }
      } else {
        final file = io.File(source);
        if (!kIsWeb && !await file.exists()) {
          throw Exception('Audio file does not exist: $source');
        }
        
        // Android-specific: Check file size and wait for file locks
        if (!kIsWeb) {
          final fileSize = await file.length();
          if (fileSize == 0) {
            throw Exception('Audio file is empty: $source');
          }
          
          // Wait a bit longer on Android for file system operations
          if (io.Platform.isAndroid) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
        
        await _audioPlayer!.setFilePath(source);
      }

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      // Android-specific error handling
      String errorMessage = 'Failed to load audio';
      
      if (e.toString().contains('Response code: 401') || e.toString().contains('401')) {
        if (io.Platform.isAndroid) {
          errorMessage = 'Authentication failed. Please log out and log back in to refresh your session.';
        } else {
          errorMessage = 'Authentication failed. Please check your login status.';
        }
      } else if (e.toString().contains('Source error') || e.toString().contains('failed to load audio')) {
        if (io.Platform.isAndroid) {
          errorMessage = 'Android audio source error. Please check file format and permissions.';
        } else {
          errorMessage = 'Audio source error. File may be corrupted or unsupported.';
        }
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Storage permission required for audio playback.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('format') || e.toString().contains('codec')) {
        if (io.Platform.isAndroid) {
          errorMessage = 'Unsupported audio format. Android supports: AAC, MP3, M4A.';
        } else {
          errorMessage = 'Unsupported audio format.';
        }
      } else {
        errorMessage = 'Failed to load audio: $e';
      }
      
      print('[AudioPlayerWidget] Error details: $e');
      throw Exception(errorMessage);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _durationSubscription?.cancel();
    try {
      _audioPlayer?.dispose();
      _fallbackPlayer?.dispose();
    } catch (e) {
      print('[AudioPlayerWidget] Error during disposal: $e');
    }
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (widget.disabled || _error != null) return;

    try {
      if (_useFallback) {
        if (_fallbackPlayer == null) return;
        if (_isPlaying) {
          await _fallbackPlayer!.pause();
        } else {
          widget.onPlay?.call();
          await _fallbackPlayer!.resume();
        }
      } else {
        if (_audioPlayer == null) return;
        if (_isPlaying) {
          await _audioPlayer!.pause();
        } else {
          widget.onPlay?.call();
          await _audioPlayer!.play();
        }
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
      if (_useFallback) {
        await _fallbackPlayer?.seek(position);
      } else {
        await _audioPlayer?.seek(position);
      }
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
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.red.withOpacity(0.1) 
              : Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.red.withOpacity(0.3) 
                : Colors.red[200]!
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red[900], fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initializeAudioPlayer,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ),
      );
    }

    if (!_initialized) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC9A24D)),
            ),
            const SizedBox(width: 16),
            Text(
              'Initializing player...',
              style: TextStyle(
                fontSize: 13, 
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white60 
                    : Colors.grey[600], 
                fontStyle: FontStyle.italic
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.06), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play button + Seek control
          Row(
            children: [
              GestureDetector(
                onTap: widget.disabled ? null : _togglePlayPause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.disabled 
                        ? Colors.grey[800] 
                        : const Color(0xFFC9A24D),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC9A24D).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, // White icon for premium feel
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform or progress bar
                    if (widget.waveformData != null && widget.waveformData!.isNotEmpty)
                      _buildWaveformBar()
                    else
                      _buildProgressBar(),
                    
                    const SizedBox(height: 6),
                    // Time and Progress indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_currentDuration),
                          style: TextStyle(
                            fontSize: 11, 
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: TextStyle(
                            fontSize: 11, 
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey[300],
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
        height: 20,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey[300],
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
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white60 
                      : Colors.grey[600]!,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white10 
                      : Colors.grey[300]!,
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
