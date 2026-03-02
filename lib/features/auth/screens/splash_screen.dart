import 'package:flutter/material.dart';
import 'dart:async';
import '../../auth/data/services/auth_service.dart';
import '../../../core/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sheenPosition;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4 seconds for the animation cycle
    );

    // Sheen position from -0.5 to 1.5 to ensure it fully clears the logo
    _sheenPosition = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Total stay duration
    await Future.delayed(const Duration(seconds: 5));
    
    if (!mounted) return;
    
    final isLoggedIn = await AuthService.isLoggedIn();
    
    if (mounted) {
      if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double progress = _sheenPosition.value;
            return Opacity(
              opacity: _logoOpacity.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: Hero(
                  tag: 'logo',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. BASE LOGO (Darker background)
                      Image.asset(
                        'assets/images/logo.png',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                      
                      // 2. SHEEN OVERLAY (Impactful Light Beam)
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.95), // Ultra Strong Core
                              Colors.white.withOpacity(0.95), // Wider Beam
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.0),
                            ],
                            // Dynamically move the stops based on the animation progress
                            stops: [
                              (progress - 0.4).clamp(0.0, 1.0),
                              (progress - 0.15).clamp(0.0, 1.0),
                              (progress - 0.05).clamp(0.0, 1.0),
                              (progress + 0.05).clamp(0.0, 1.0),
                              (progress + 0.15).clamp(0.0, 1.0),
                              (progress + 0.4).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcIn,
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                          color: Colors.white, // This color will be masked by the shader
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
