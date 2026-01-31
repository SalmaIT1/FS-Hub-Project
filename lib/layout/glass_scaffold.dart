import 'package:flutter/material.dart';
import '../navigation/glass_navigation_bar.dart';

class GlassScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? leadingActions;
  final List<Widget>? trailingActions;
  final Widget? bottomBar;
  final Widget child;
  final double navigationBarHeight;

  const GlassScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBackPressed,
    this.leadingActions,
    this.trailingActions,
    this.bottomBar,
    required this.child,
    this.navigationBarHeight = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassNavigationBar(
        title: title,
        subtitle: subtitle,
        showBackButton: showBackButton,
        onBackPressed: onBackPressed,
        leadingActions: leadingActions,
        trailingActions: trailingActions,
        bottom: bottomBar,
        height: navigationBarHeight,
      ),
      body: child,
    );
  }
}