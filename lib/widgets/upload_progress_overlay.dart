import 'package:flutter/material.dart';

class UploadProgressOverlay extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final String label;
  UploadProgressOverlay({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      child: Center(
        child: Container(
          width: 260,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: Colors.white)),
            SizedBox(height: 12),
            LinearProgressIndicator(value: progress, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(Color(0xFFFFD700))),
          ]),
        ),
      ),
    );
  }
}
