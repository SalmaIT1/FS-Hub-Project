import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fs_hub/core/state/location_controller.dart';

class DigitalClockCard extends StatefulWidget {
  final bool isDark;
  final bool isFr;

  const DigitalClockCard({
    super.key,
    required this.isDark,
    required this.isFr,
  });

  @override
  State<DigitalClockCard> createState() => _DigitalClockCardState();
}

class _DigitalClockCardState extends State<DigitalClockCard> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Format: HH:MM:SS
    final timeString = DateFormat('HH:mm:ss').format(_now);
    // Format: Day, DD Mon YYYY
    final dateString = DateFormat(widget.isFr ? 'EEEE, d MMM yyyy' : 'EEEE, MMM d, yyyy', widget.isFr ? 'fr' : 'en').format(_now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: widget.isDark 
            ? const Color(0xFF141414)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC9A24D).withOpacity(widget.isDark ? 0.3 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC9A24D).withOpacity(widget.isDark ? 0.08 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The Digital Clock (Calculator-style Mono Font)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeString,
              style: TextStyle(
                fontFamily: 'Courier', // Monospaced digital feel without external fonts
                fontSize: 56,
                height: 1.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
                color: widget.isDark ? const Color(0xFFC9A24D) : const Color(0xFF96731E),
                shadows: [
                  Shadow(
                    color: const Color(0xFFC9A24D).withOpacity(widget.isDark ? 0.6 : 0.3),
                    blurRadius: 18,
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Date
          Text(
            dateString.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: widget.isDark ? Colors.white70 : const Color(0xFF2D3138),
            ),
          ),
          const SizedBox(height: 12),
          
          // Location (Icon + Text)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded, 
                  size: 14, 
                  color: widget.isDark ? const Color(0xFFC9A24D) : const Color(0xFF96731E)
                ),
                const SizedBox(width: 8),
                Text(
                  context.watch<LocationController>().locationLabel.isNotEmpty
                      ? context.watch<LocationController>().locationLabel
                      : (widget.isFr
                          ? 'Siège Principal — Opérations'
                          : 'Main Headquarters — Operations'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: widget.isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

