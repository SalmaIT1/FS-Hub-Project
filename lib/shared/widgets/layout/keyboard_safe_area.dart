import 'package:flutter/material.dart';

/// Keyboard safe area that adjusts for keyboard height
class KeyboardSafeArea extends StatelessWidget {
  final Widget child;
  final bool maintainBottomViewPadding;

  const KeyboardSafeArea({
    super.key,
    required this.child,
    this.maintainBottomViewPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      maintainBottomViewPadding: maintainBottomViewPadding,
      child: child,
    );
  }
}
