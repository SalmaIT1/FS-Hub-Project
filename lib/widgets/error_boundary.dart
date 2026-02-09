import 'package:flutter/material.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  ErrorBoundary({required this.child});

  @override
  _ErrorBoundaryState createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  late ErrorWidgetBuilder _prevBuilder;

  @override
  void initState() {
    super.initState();
    _prevBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Container(
        color: Color(0xFF111111),
        padding: EdgeInsets.all(12),
        child: Center(child: Text('Something went wrong', style: TextStyle(color: Colors.white))),
      );
    };
  }

  @override
  void dispose() {
    ErrorWidget.builder = _prevBuilder;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
