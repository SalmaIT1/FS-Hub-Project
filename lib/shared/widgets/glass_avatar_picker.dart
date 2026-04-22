import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fs_hub/shared/widgets/authenticated_image.dart';

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
          _selectedImage = image;
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
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
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
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
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
                color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
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
      return FutureBuilder<Uint8List>(
        future: (_selectedImage as XFile).readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
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
    }

    if (widget.initialImageUrl != null) {
      return AuthenticatedImage(
        url: widget.initialImageUrl!,
        fit: BoxFit.cover,
        errorWidget: _buildPlaceholder(isDark),
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
