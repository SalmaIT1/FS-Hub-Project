import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart';
import 'services/auth_service.dart';
import 'pages/auth/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final loggedIn = await AuthService.isLoggedIn();
    
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => loggedIn 
              ? const MyHomePage(title: 'FS HUB')
              : const GlassLoginPage(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/signature.jpeg'),
            fit: BoxFit.contain, // Changed from BoxFit.cover to BoxFit.contain
          ),
        ),
      ),
    );
  }
}
