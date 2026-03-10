import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../employees/services/employee_service.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/widgets/glass_widgets.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_app_bar.dart';
import 'package:fs_hub/shared/widgets/luxury/luxury_status_dialog.dart';
import '../../../email/services/email_service.dart';
import '../../data/services/auth_service.dart';

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

  Future<void> _handleRequestPasswordReset(SettingsController settings) async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _message = settings.translate('enter_email_address');
        _isError = true;
      });
      return;
    }

    setState(() { 
      _isLoading = true; 
      _message = null; 
    });

    try {
      final result = await AuthService.forgotPassword(_emailController.text.trim());
      
      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success']) {
          LuxuryStatusDialog.show(
            context,
            isSuccess: true,
            title: 'Protocol Executed',
            message: result['message'] ?? 'A new password has been generated and sent to your email.',
          );
          _message = settings.translate('reset_request_submitted');
          _isError = false;
        } else {
          String errorMsg = result['message'] ?? settings.translate('failed_submit_reset');
          
          LuxuryStatusDialog.show(
            context,
            isSuccess: false,
            title: 'Protocol Error',
            message: errorMsg,
          );
          
          setState(() {
            _message = errorMsg;
            _isError = true;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '${settings.translate('error_occurred')}: ${e.toString()}';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();
    
    return LuxuryScaffold(
      title: settings.translate('reset_password'),
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
                          const Icon(
                            Icons.lock_reset,
                            size: 48,
                            color: Color(0xFFD4AF37),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            settings.translate('reset_password'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings.translate('enter_email_to_reset'),
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
                              label: settings.translate('email_address'),
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 24),
                            GlassButton(
                              text: settings.translate('request_password_reset_btn'),
                              onPressed: _isLoading ? null : () => _handleRequestPasswordReset(settings),
                              isLoading: _isLoading,
                            ),
                          ],
                          
                          if (_message != null && !_isError) ...[
                            const SizedBox(height: 24),
                            GlassButton(
                              text: settings.translate('back_to_login'),
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
                                    const Icon(
                                      Icons.info_outline,
                                      color: Color(0xFFD4AF37),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      settings.translate('how_it_works'),
                                      style: const TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  settings.translate('reset_steps'),
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


