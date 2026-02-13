import 'dart:ui';
import 'package:flutter/material.dart';

class LuxurySearchInline extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onClear;

  const LuxurySearchInline({
    super.key,
    required this.hintText,
    required this.onQueryChanged,
    this.onClear,
  });

  @override
  State<LuxurySearchInline> createState() => _LuxurySearchInlineState();
}

class _LuxurySearchInlineState extends State<LuxurySearchInline> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    setState(() {
      _hasText = text.isNotEmpty;
    });
    widget.onQueryChanged(text);
  }

  void _clearText() {
    _controller.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: TextField(
        controller: _controller,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? Colors.white54 : Colors.black45,
            size: 20,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark ? Colors.white54 : Colors.black45,
                    size: 20,
                  ),
                  onPressed: _clearText,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}