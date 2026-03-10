import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fs_hub/core/theme/app_theme.dart';

class LuxuryStatusDialog extends StatefulWidget {
  final bool isSuccess;
  final String title;
  final String message;
  final VoidCallback? onDismiss;

  const LuxuryStatusDialog({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.message,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isSuccess,
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => LuxuryStatusDialog(
        isSuccess: isSuccess,
        title: title,
        message: message,
      ),
    );
  }

  @override
  State<LuxuryStatusDialog> createState() => _LuxuryStatusDialogState();
}

class _LuxuryStatusDialogState extends State<LuxuryStatusDialog> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _circleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _circleController,
      curve: Curves.elasticOut,
    );

    _circleController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _circleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.isSuccess ? Colors.greenAccent : Colors.redAccent;
    final goldColor = const Color(0xFFD4AF37);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(1.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [goldColor.withOpacity(0.4), goldColor.withOpacity(0.05), goldColor.withOpacity(0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: goldColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151515).withOpacity(0.8) : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Icon Section - Minimalist
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withOpacity(0.05),
                                border: Border.all(color: accentColor.withOpacity(0.1), width: 1),
                              ),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [accentColor.withOpacity(0.6), accentColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.isSuccess ? Icons.check_rounded : Icons.close_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Title - Ultra Discrete
                      Text(
                        widget.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: goldColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Message
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Action Button - Slim
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onDismiss?.call();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [goldColor, const Color(0xFF8B6914)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: goldColor.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              widget.isSuccess ? 'CONTINUE' : 'RETRY',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

