import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  
  int _step = 1; // 1: Request, 2: Confirm
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  Future<void> _handleRequest() async {
    setState(() { _isLoading = true; _message = null; });
    final res = await AuthService.requestPasswordReset(_emailController.text);
    setState(() {
      _isLoading = false;
      if (res['error'] != null) {
        _message = res['error'];
        _isError = true;
      } else {
        _message = res['message'];
        _isError = false;
        _step = 2;
      }
    });
  }

  Future<void> _handleConfirm() async {
    setState(() { _isLoading = true; _message = null; });
    final res = await AuthService.confirmPasswordReset(
      _emailController.text,
      _codeController.text,
      _passwordController.text,
    );
    setState(() {
      _isLoading = false;
      if (res['error'] != null) {
        _message = res['error'];
        _isError = true;
      } else {
        _message = res['message'];
        _isError = false;
        // Success! Redirect back to login after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
            if (_message != null)
              Text(_message!, style: TextStyle(color: _isError ? Colors.red : Colors.green)),
            const SizedBox(height: 16),
            if (_step == 1) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Enter your Email'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRequest,
                child: const Text('Send Reset Code'),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Enter 6-digit Code'),
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleConfirm,
                child: const Text('Reset Password'),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
);
  }
}
