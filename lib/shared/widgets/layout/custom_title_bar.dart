import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:fs_hub/core/theme/app_theme.dart';

class CustomTitleBar extends StatelessWidget {
  final Widget child;

  const CustomTitleBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          const WindowTitleBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final textColor = isDark ? AppTheme.accentGold : Colors.black;

    return Container(
      height: 38,
      color: backgroundColor,
      child: Row(
        children: [
          // App Logo & Title (Draggable Area)
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 18),
                    const SizedBox(width: 10),
                    Text(
                      'FS HUB',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Window Control Buttons
          const WindowCaptionButtons(),
        ],
      ),
    );
  }
}

class WindowCaptionButtons extends StatelessWidget {
  const WindowCaptionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _TitleBarButton(
          icon: Icons.remove_rounded,
          onPressed: () => windowManager.minimize(),
          hoverColor: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          isDark: isDark,
          buttonType: _ButtonType.minimize,
        ),
        _TitleBarButton(
          icon: Icons.crop_square_rounded,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
          hoverColor: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          isDark: isDark,
          buttonType: _ButtonType.maximize,
        ),
        _TitleBarButton(
          icon: Icons.close_rounded,
          onPressed: () => windowManager.close(),
          hoverColor: Colors.red.withOpacity(0.85),
          isDark: isDark,
          isClose: true,
          buttonType: _ButtonType.close,
        ),
      ],
    );
  }
}

enum _ButtonType { minimize, maximize, close }

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final bool isDark;
  final bool isClose;
  final _ButtonType buttonType;

  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    required this.isDark,
    this.isClose = false,
    required this.buttonType,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    
    if (widget.isDark) {
      iconColor = _isHovered && widget.isClose ? Colors.white : AppTheme.accentGold;
    } else {
      // Light Mode: Colored buttons logic or black text
      if (_isHovered) {
        iconColor = Colors.white;
      } else {
        switch (widget.buttonType) {
          case _ButtonType.minimize:
            iconColor = const Color(0xFF5E9BF0); // Blueish
            break;
          case _ButtonType.maximize:
            iconColor = const Color(0xFF4ABF8A); // Greenish
            break;
          case _ButtonType.close:
            iconColor = const Color(0xFFF07E4A); // Orangesh
            break;
        }
      }
    }

    // Adjust hover color for light mode to match button color
    Color currentHoverColor = widget.hoverColor;
    if (!widget.isDark && _isHovered) {
      switch (widget.buttonType) {
        case _ButtonType.minimize:
          currentHoverColor = const Color(0xFF5E9BF0);
          break;
        case _ButtonType.maximize:
          currentHoverColor = const Color(0xFF4ABF8A);
          break;
        case _ButtonType.close:
          currentHoverColor = const Color(0xFFF07E4A);
          break;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: double.infinity,
          color: _isHovered ? currentHoverColor : Colors.transparent,
          child: Center(
            child: Icon(
              widget.icon,
              size: 14,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

