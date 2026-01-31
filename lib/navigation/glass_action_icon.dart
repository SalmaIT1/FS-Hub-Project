import 'dart:ui';
import 'package:flutter/material.dart';

class GlassActionIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final double iconSize;
  final String? tooltip;

  const GlassActionIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 36,
    this.iconSize = 18,
    this.tooltip,
  });

  @override
  State<GlassActionIcon> createState() => _GlassActionIconState();
}

class _GlassActionIconState extends State<GlassActionIcon> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = widget.color ?? (isDark ? Colors.white : Colors.black);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _animationController.forward();
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _animationController.reverse();
              if (widget.onPressed != null) {
                widget.onPressed!();
              }
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              _animationController.reverse();
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.08 * _opacityAnimation.value)
                    : Colors.black.withOpacity(0.04 * _opacityAnimation.value),
                borderRadius: BorderRadius.circular(widget.size / 2),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.12 * _opacityAnimation.value)
                      : Colors.black.withOpacity(0.08 * _opacityAnimation.value),
                  width: 1.0,
                ),
              ),
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: effectiveColor.withOpacity(_opacityAnimation.value),
              ),
            ),
          ),
        );
      },
    );
  }
}