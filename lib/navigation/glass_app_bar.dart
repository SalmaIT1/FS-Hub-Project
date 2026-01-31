import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class GlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? leadingActions;
  final List<Widget>? trailingActions;
  final Widget? bottom;
  final double blurSigma;
  final double height;
  final bool showBottomLine;

  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBackPressed,
    this.leadingActions,
    this.trailingActions,
    this.bottom,
    this.blurSigma = 10.0,
    this.height = 100.0,
    this.showBottomLine = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();
}

class _GlassAppBarState extends State<GlassAppBar> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          height: widget.height + statusBarHeight,
          child: Stack(
            children: [
              // Status bar padding
              Container(
                height: statusBarHeight,
                color: Colors.transparent,
              ),
              // Glass AppBar content
              Positioned(
                top: statusBarHeight,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: widget.blurSigma,
                      sigmaY: widget.blurSigma,
                    ),
                    child: Container(
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.04),
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                            width: widget.showBottomLine ? 1.0 : 0.0,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildContent(context, isDark),
                          ),
                          if (widget.bottom != null) ...[
                            Container(
                              height: 1,
                              color: isDark 
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.04),
                            ),
                            Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: widget.bottom,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Leading actions (back button and custom actions)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                if (widget.showBackButton)
                  _buildBackButton(isDark),
                if (widget.leadingActions != null)
                  ...widget.leadingActions!,
              ],
            ),
          ),
          // Center content (title and subtitle)
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Trailing actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.trailingActions != null)
                  ...widget.trailingActions!,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        if (widget.onBackPressed != null) {
          widget.onBackPressed!();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          CupertinoIcons.back,
          size: 18,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}