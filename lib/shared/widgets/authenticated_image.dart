import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fs_hub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fs_hub/core/utils/url_utils.dart';

/// An image widget that automatically includes the authentication token in headers.
///
/// Uses a [StatefulWidget] so the token is fetched **once** and cached for the
/// lifetime of the widget — avoiding per-frame async rebuilds and flicker that
/// would occur if a plain [FutureBuilder] were used in a list.
class AuthenticatedImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final ImageLoadingBuilder? loadingBuilder;

  const AuthenticatedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.loadingBuilder,
  });

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  String? _token;
  bool _tokenLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch if the URL changed (new image).
    if (oldWidget.url != widget.url) {
      _loadToken();
    }
  }

  Future<void> _loadToken() async {
    final token = await AuthRemoteDatasource.getAccessToken();
    if (mounted) {
      setState(() {
        _token = token;
        _tokenLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;

    if (url.isEmpty) {
      return widget.errorWidget ?? const Center(child: Icon(Icons.broken_image));
    }

    // Blob / data-URL — no auth needed.
    if (url.startsWith('blob:') || url.startsWith('data:')) {
      if (url.startsWith('data:')) {
        try {
          final parts = url.split(',');
          if (parts.length > 1) {
            final bytes = base64Decode(parts[1].replaceAll(RegExp(r'\s+'), ''));
            return Image.memory(
              bytes,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              errorBuilder: (context, error, stackTrace) =>
                  widget.errorWidget ?? const Center(child: Icon(Icons.broken_image)),
            );
          }
        } catch (e) {
          debugPrint('[AuthenticatedImage] Base64 decode error: $e');
        }
      }
      
      return Image.network(
        url,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        loadingBuilder: widget.loadingBuilder,
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ?? const Center(child: Icon(Icons.broken_image)),
      );
    }

    // Show placeholder while awaiting first token fetch.
    if (!_tokenLoaded) {
      return widget.placeholder ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    }

    // On Web, append token to URL (browser <img> tags ignore custom headers).
    final authenticatedUrl =
        kIsWeb ? UrlUtils.appendToken(url, _token) : url;

    final headers = _token != null
        ? {'Authorization': 'Bearer $_token'}
        : <String, String>{};

    return Image.network(
      authenticatedUrl,
      headers: headers,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: (context, error, stackTrace) {
        // Only log failures to avoid noise.
        debugPrint('[AuthenticatedImage] Failed to load: $url — $error');
        return widget.errorWidget ?? const Center(child: Icon(Icons.broken_image));
      },
    );
  }
}
