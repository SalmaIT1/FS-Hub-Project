import 'package:flutter/material.dart';

/// Safe scroll view that prevents nested scroll issues
class SafeScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsetsGeometry? padding;

  const SafeScrollView({
    super.key,
    required this.child,
    this.controller,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: physics ?? const ClampingScrollPhysics(),
      scrollDirection: scrollDirection,
      reverse: reverse,
      padding: padding,
      child: child,
    );
  }
}
