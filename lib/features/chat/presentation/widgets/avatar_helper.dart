import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fs_hub/shared/widgets/authenticated_image.dart';
import 'package:fs_hub/core/utils/url_utils.dart';

/// Helper to resolve chat avatars, supporting both network URLs and base64 strings.
class AvatarHelper {
  /// Transforms a raw URL or potential base64 string into a valid ImageProvider.
  /// Clean and decode base64 string
  static Uint8List? _decodeBase64(String CleanedBase64) {
    try {
      return base64Decode(CleanedBase64);
    } catch (e) {
      print('[AvatarHelper] Decoding error: $e');
      return null;
    }
  }

  /// Clean base64 string from any potential weird characters/newlines
  static String _cleanBase64(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '').trim();
  }

  /// Higher-level method that returns a Widget, matching EmployeeCard's robust logic.
  static Widget buildAvatar(String? avatarUrl, {double size = 44, bool isGroup = false, String? initials}) {
    final normalizedUrl = UrlUtils.normalizeAvatarUrl(avatarUrl);
    print('[AvatarHelper] Building avatar for URL of length: ${normalizedUrl.length}');
    
    if (normalizedUrl.isEmpty) {
      print('[AvatarHelper] URL is empty, showing placeholder');
      return _buildPlaceholder(size, isGroup, initials);
    }

    // Prepare the ImageProvider
    ImageProvider? provider;

    if (normalizedUrl.startsWith('data:')) {
      try {
        final base64Part = normalizedUrl.split(',').last;
        final bytes = _decodeBase64(_cleanBase64(base64Part));
        if (bytes != null) {
          provider = MemoryImage(bytes);
          print('[AvatarHelper] Created MemoryImage from data URL');
        } else {
          print('[AvatarHelper] Failed to decode base64 bytes');
        }
      } catch (e) {
        print('[AvatarHelper] Base64 error: $e');
      }
    } else if (normalizedUrl.startsWith('http')) {
      provider = NetworkImage(normalizedUrl);
      print('[AvatarHelper] Created NetworkImage for: $normalizedUrl');
    }

    if (provider == null) {
      print('[AvatarHelper] Provider is null, showing placeholder');
      return _buildPlaceholder(size, isGroup, initials);
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: provider is NetworkImage
          ? AuthenticatedImage(
              url: (provider as NetworkImage).url,
              fit: BoxFit.cover,
              errorWidget: _buildPlaceholder(size, isGroup, initials),
            )
          : Image(
              image: provider,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('[AvatarHelper] Image widget error: $error');
                return _buildPlaceholder(size, isGroup, initials);
              },
            ),
    );
  }

  static Widget _buildPlaceholder(double size, bool isGroup, String? initials) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isGroup 
            ? [const Color(0xFF6C63FF), const Color(0xFF3F3D56)]
            : [const Color(0xFFFFD700), const Color(0xFF8B6914)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: (initials != null && initials.isNotEmpty)
            ? Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Icon(
                isGroup ? Icons.group_rounded : Icons.person_rounded,
                color: Colors.white,
                size: size * 0.5,
              ),
      ),
    );
  }

  /// Transforms a raw URL or potential base64 string into a valid ImageProvider.
  /// Kept for backward compatibility if needed elsewhere.
  static ImageProvider? getProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    final url = avatarUrl.trim();

    if (url.startsWith('data:')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String.trim()));
      } catch (_) { return null; }
    }

    if (url.startsWith('http') && url.contains('/media/')) {
      final parts = url.split('/media/');
      if (parts.length > 1 && parts.last.length > 50) {
        try { return MemoryImage(base64Decode(parts.last.trim())); } catch (_) {}
      }
    }

    if (url.length > 50 && !url.startsWith('http')) {
      try { return MemoryImage(base64Decode(url.trim())); } catch (_) {}
    }

    if (url.startsWith('http')) return NetworkImage(url);
    
    return null;
  }
}
