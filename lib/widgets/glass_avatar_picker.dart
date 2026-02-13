import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class GlassAvatarPicker extends StatefulWidget {
  final String? initialImageUrl;
  final Function(dynamic) onImageSelected;
  final double size;

  const GlassAvatarPicker({
    super.key,
    this.initialImageUrl,
    required this.onImageSelected,
    this.size = 120,
  });

  @override
  State<GlassAvatarPicker> createState() => _GlassAvatarPickerState();
}

class _GlassAvatarPickerState extends State<GlassAvatarPicker> {
  dynamic _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _selectedImage = image;
          } else {
            _selectedImage = image.path;
          }
        });
        widget.onImageSelected(_selectedImage);
      }
    } catch (e) {
      
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                  child: _buildImageWidget(isDark),
                ),
              ),
            ),
          ),
          if (_selectedImage == null && widget.initialImageUrl == null)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(bool isDark) {
    if (_selectedImage != null) {
      if (kIsWeb) {
        return FutureBuilder<String>(
          future: (_selectedImage as XFile).readAsBytes().then((bytes) {
            return 'data:image/jpeg;base64,${Uri.encodeComponent(String.fromCharCodes(bytes))}';
          }),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(isDark);
                },
              );
            }
            return _buildPlaceholder(isDark);
          },
        );
      } else {
        return Image.network(
          _selectedImage as String,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(isDark);
          },
        );
      }
    }

    if (widget.initialImageUrl != null) {
      return Image.network(
        widget.initialImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(isDark);
        },
      );
    }

    return _buildPlaceholder(isDark);
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Icon(
        Icons.person_outline,
        size: widget.size * 0.4,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
    );
  }
}
