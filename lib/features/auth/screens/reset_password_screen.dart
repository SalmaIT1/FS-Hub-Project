import 'dart:ui';
import 'package:flutter/material.dart';
import '../data/services/auth_service.dart';
import '../../employees/services/employee_service.dart';
import '../../email/services/email_service.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../shared/widgets/glass_text_field.dart';
import '../../../shared/widgets/glass_button.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  Future<void> _handleRequestPasswordReset() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _message = 'Please enter your email address';
        _isError = true;
      });
      return;
    }

    setState(() { 
      _isLoading = true; 
      _message = null; 
    });

    try {
      // Find the user by email to get their ID
      final employee = await EmployeeService.getEmployeeByEmail(_emailController.text.trim());
      
      if (employee == null) {
        setState(() {
          _isLoading = false;
          _message = 'No account found with this email address. Please check your email and try again.';
          _isError = true;
        });
        return;
      }

      // Create password reset demand with the actual user ID
      final demandData = {
        'type': 'password_reset',
        'description': 'Password reset request for email: ${_emailController.text.trim()}',
        'requesterId': employee.id ?? '0', // Use the actual user ID, fallback to 0 if null
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'email': _emailController.text.trim(), // Store email for reference
      };

      final result = await EmployeeService.createDemand(demandData);
      
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _message = 'Password reset request submitted successfully. An administrator will review your request and send you a new password via email.';
          _isError = false;
        } else {
          // Check if it's a backend connection issue
          if (result['message']?.contains('connection') == true || 
              result['message']?.contains('MySQL') == true) {
            _message = 'Server is experiencing technical difficulties. Please try again in a few minutes or contact support.';
          } else {
            _message = result['message'] ?? 'Failed to submit password reset request';
          }
          _isError = true;
        }
      });

      // Send notification to admin
      if (result['success']) {
        await EmailService.sendPasswordResetRequestNotification(
          adminEmail: EmailService.adminEmail,
          userEmail: _emailController.text.trim(),
          userName: employee.fullName, // Use the actual user name
          requestId: result['demandId'] ?? 'Unknown',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'An error occurred: ${e.toString()}';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return LuxuryScaffold(
      title: 'Reset Password',
      isPremium: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: isDark 
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_reset,
                            size: 48,
                            color: const Color(0xFFD4AF37),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Password Reset',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your email address to request a password reset',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          if (_message != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _isError 
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isError 
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isError ? Icons.error_outline : Icons.check_circle_outline,
                                    color: _isError ? Colors.red : Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: TextStyle(
                                        color: _isError ? Colors.red : Colors.green,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          if (_message == null || _isError) ...[
                            GlassTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 24),
                            GlassButton(
                              text: 'REQUEST PASSWORD RESET',
                              onPressed: _isLoading ? null : _handleRequestPasswordReset,
                              isLoading: _isLoading,
                            ),
                          ],
                          
                          if (_message != null && !_isError) ...[
                            const SizedBox(height: 24),
                            GlassButton(
                              text: 'BACK TO LOGIN',
                              onPressed: () => Navigator.of(context).pop(),
                              isLoading: false,
                            ),
                          ],
                          
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD4AF37).withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: const Color(0xFFD4AF37),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'How it works:',
                                      style: TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '1. Submit your email address\n2. Administrator reviews your request\n3. You receive a new password via email\n4. Log in and change your password',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
