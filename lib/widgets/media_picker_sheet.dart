import 'package:flutter/material.dart';

class MediaPickerSheet extends StatelessWidget {
  final void Function(String type) onPick;
  MediaPickerSheet({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Color(0xFF0E0E0E), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _tile(context, 'Photo Library', 'image'),
        _tile(context, 'Camera', 'camera'),
        _tile(context, 'File', 'file'),
        _tile(context, 'Voice Note', 'audio'),
      ]),
    );
  }

  Widget _tile(BuildContext ctx, String title, String type) {
    return ListTile(
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: () {
        onPick(type);
        Navigator.of(ctx).pop();
      },
    );
  }
}
