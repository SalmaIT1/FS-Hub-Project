import 'package:flutter/material.dart';

enum Breakpoint {
  mobile,
  tablet,
  desktop,
}

class BreakpointDetector extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;
  final Widget Function(Breakpoint breakpoint)? builder;

  const BreakpointDetector({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
    this.builder,
  });

  static Breakpoint getCurrentBreakpoint(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return Breakpoint.mobile;
    if (width < 1024) return Breakpoint.tablet;
    return Breakpoint.desktop;
  }

  static bool isMobile(BuildContext context) => getCurrentBreakpoint(context) == Breakpoint.mobile;
  static bool isTablet(BuildContext context) => getCurrentBreakpoint(context) == Breakpoint.tablet;
  static bool isDesktop(BuildContext context) => getCurrentBreakpoint(context) == Breakpoint.desktop;

  @override
  Widget build(BuildContext context) {
    if (builder != null) {
      return builder!(getCurrentBreakpoint(context));
    }

    final breakpoint = getCurrentBreakpoint(context);
    switch (breakpoint) {
      case Breakpoint.mobile:
        return mobile;
      case Breakpoint.tablet:
        return tablet;
      case Breakpoint.desktop:
        return desktop;
    }
  }
}