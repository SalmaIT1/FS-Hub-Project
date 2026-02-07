import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatefulWidget {
  final String title;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const GlassCard({
    super.key,
    required this.title,
    required this.caption,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: BoxConstraints(minHeight: widget.isPrimary ? 130 : 110),
              decoration: BoxDecoration(
                color: isDark 
                    ? (widget.isPrimary ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.08))
                    : (widget.isPrimary ? Colors.black.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark 
                      ? (widget.isPrimary ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.12))
                      : (widget.isPrimary ? Colors.black.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                  width: widget.isPrimary ? 1.2 : 1.0,
                ),
                boxShadow: [
                  if (_isPressed || widget.isPrimary)
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(widget.isPrimary ? 0.3 : 0.2),
                      blurRadius: widget.isPrimary ? 18 : 15,
                      spreadRadius: widget.isPrimary ? 1.5 : 1,
                    ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: widget.isPrimary ? 16 : 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        widget.icon, 
                        color: isDark ? Colors.white : Colors.black, 
                        size: 22
                      ),
                      Icon(
                        Icons.north_east, 
                        color: isDark ? Colors.white24 : Colors.black26, 
                        size: 14
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: widget.isPrimary ? 13 : 12,
                          fontWeight: FontWeight.w800, // Increased font weight
                          letterSpacing: widget.isPrimary ? 1.0 : 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.caption,
                        style: TextStyle(
                          color: isDark 
                              ? Colors.white.withOpacity(0.5) // Reduced opacity for clearer hierarchy
                              : Colors.black.withOpacity(0.6),
                          fontSize: widget.isPrimary ? 11 : 10,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
