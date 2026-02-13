import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';

/// Generates waveform visualization data from PCM audio bytes
/// 
/// Converts raw audio samples into a compact representation suitable for
/// visualization or transmission alongside voice note metadata
class WaveformGenerator {
  /// Generate waveform data from M4A audio file bytes
  /// 
  /// Returns base64-encoded waveform samples suitable for storing in DB
  /// 
  /// For AAC/M4A files, we'll extract a representative sample count
  /// rather than parsing the full MP4 container (complex)
  /// 
  /// In production, use FFmpeg to extract PCM samples from M4A
  static String generateWaveformFromM4A(List<int> audioBytes) {
    // For AAC/M4A files, we cannot easily extract raw PCM without
    // parsing MP4 container or using FFmpeg
    // 
    // As a practical fallback that works offline:
    // Generate a waveform based on the file size variance
    // (This is a reasonable approximation for visual feedback)
    
    return _generateApproximateWaveform(audioBytes);
  }
  
  /// Generate waveform from raw PCM samples (float32 or int16)
  static String generateWaveformFromPCM(List<int> pcmBytes, {
    int sampleRate = 44100,
    int bitsPerSample = 16,
  }) {
    try {
      final samples = _extractPCMSamples(pcmBytes, bitsPerSample);
      return _waveformSamplesToBase64(samples, sampleRate);
    } catch (e) {
      print('[WaveformGenerator] Error parsing PCM: $e');
      return _generateApproximateWaveform(pcmBytes);
    }
  }
  
  /// Extract raw PCM samples from byte data
  static List<double> _extractPCMSamples(List<int> data, int bitsPerSample) {
    if (data.isEmpty) return [];
    
    final samples = <double>[];
    final bytesPerSample = bitsPerSample ~/ 8;
    
    if (bitsPerSample == 16) {
      // Little-endian int16
      for (int i = 0; i < data.length - 1; i += 2) {
        int sample = (data[i] & 0xFF) | ((data[i + 1] & 0x7F) << 8);
        if ((data[i + 1] & 0x80) != 0) {
          sample = -(0x10000 - sample);
        }
        samples.add(sample / 32768.0); // Normalize to [-1, 1]
      }
    }
    
    return samples;
  }
  
  /// Convert PCM samples to base64 waveform representation
  static String _waveformSamplesToBase64(List<double> samples, int sampleRate) {
    if (samples.isEmpty) return '';
    
    // Target ~100 visualization points per second of audio
    final targetCount = max(32, (samples.length / sampleRate * 100).toInt());
    final downsampleFactor = max(1, samples.length ~/ targetCount);
    
    final waveform = <double>[];
    for (int i = 0; i < samples.length; i += downsampleFactor) {
      final chunk = samples.sublist(
        i,
        min(i + downsampleFactor, samples.length),
      );
      
      if (chunk.isNotEmpty) {
        // Take RMS amplitude of chunk
        final rms = sqrt(chunk.fold<double>(0, (sum, s) => sum + s * s) / chunk.length);
        waveform.add(rms);
      }
    }
    
    // Encode as bytes: each amplitude as uint8 (0-255)
    final bytes = <int>[];
    for (final amp in waveform) {
      bytes.add((amp * 255).toInt().clamp(0, 255));
    }
    
    return base64Encode(bytes);
  }
  
  /// Generate approximate waveform from file size analysis
  /// 
  /// When we can't parse the audio format, create a pseudo-waveform
  /// based on file variance for visual feedback
  static String _generateApproximateWaveform(List<int> audioBytes) {
    if (audioBytes.length < 64) {
      return base64Encode([64]); // Single flat sample
    }
    
    // Sample the file in chunks to approximate audio characteristics
    final chunkSize = max(64, audioBytes.length ~/ 100);
    final waveform = <int>[];
    
    for (int i = 0; i < audioBytes.length; i += chunkSize) {
      final chunk = audioBytes.sublist(
        i,
        min(i + chunkSize, audioBytes.length),
      );
      
      // Calculate "energy" of chunk as byte variance
      final mean = chunk.fold<int>(0, (a, b) => a + b) ~/ chunk.length;
      final variance = chunk.fold<int>(0, (a, b) => a + (b - mean).abs()) ~/ chunk.length;
      
      // Map to 0-255 range
      waveform.add(variance.clamp(0, 255));
    }
    
    return base64Encode(waveform);
  }
  
  /// Decode base64 waveform back to amplitude list (0-1)
  static List<double> decodeWaveform(String base64Data) {
    if (base64Data.isEmpty) return [];
    try {
      final bytes = base64Decode(base64Data);
      return bytes.map<double>((b) => b / 255.0).toList();
    } catch (e) {
      print('[WaveformGenerator] Error decoding waveform: $e');
      return [];
    }
  }
  
  /// Get approximate duration from file size and encoding
  /// 
  /// AAC at 128kbps ≈ 16KB per second
  static int estimateDurationMs(List<int> audioBytes) {
    if (audioBytes.isEmpty) return 0;
    // Rough estimate: 16KB per second at 128kbps AAC
    const bitrate = 128000; // bits per second
    const bytesPerMs = bitrate / 8 / 1000;
    return (audioBytes.length / bytesPerMs).toInt();
  }
}
