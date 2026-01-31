import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

class GlassNavigationBar extends StatefulWidget implements PreferredSizeWidget {
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
  final bool scrollHideEnabled;
  final ScrollController? scrollController;
  final bool? isHidden;

  const GlassNavigationBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBackPressed,
    this.leadingActions,
    this.trailingActions,
    this.bottom,
    this.blurSigma = 10.0,
    this.height = 80.0,
    this.showBottomLine = true,
    this.scrollHideEnabled = false,
    this.scrollController,
    this.isHidden,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  State<GlassNavigationBar> createState() => _GlassNavigationBarState();
}

class _GlassNavigationBarState extends State<GlassNavigationBar> with TickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();

    if (widget.scrollHideEnabled && widget.scrollController != null) {
      widget.scrollController!.addListener(_handleScroll);
    }
  }

  void _handleScroll() {
    if (!widget.scrollHideEnabled) return;
    
    final direction = widget.scrollController!.position.userScrollDirection;
    
    if (direction == ScrollDirection.forward && !_isVisible) {
      setState(() => _isVisible = true);
    } else if (direction == ScrollDirection.reverse && _isVisible) {
      setState(() => _isVisible = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (widget.scrollHideEnabled && widget.scrollController != null) {
      widget.scrollController!.removeListener(_handleScroll);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final opacity = widget.isHidden != null ? (widget.isHidden! ? 0.0 : 1.0) : (_isVisible ? 1.0 : 0.0);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: widget.height + statusBarHeight,
            child: Stack(
              children: [
                // Status bar padding
                Container(
                  height: statusBarHeight,
                  color: Colors.transparent,
                ),
                // Glass Navigation Bar content
                Positioned(
                  top: statusBarHeight,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
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
                              color: const Color(0xFFFFD700).withOpacity(0.4), // Soft gold underline
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
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