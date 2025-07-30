import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:new_flutter/services/auth_service.dart';
import 'package:new_flutter/services/logger_service.dart';
import 'package:new_flutter/theme/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _message = '';
  String _error = '';
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔑 ForgotPasswordPage.initState() called');
  }

  @override
  void dispose() {
    debugPrint('🗑️ ForgotPasswordPage.dispose() called');
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    debugPrint('🔑 ForgotPasswordPage._handlePasswordReset() called');
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _error = '';
      _message = '';
      _isLoading = true;
    });

    try {
      debugPrint('🔄 ForgotPasswordPage - Sending password reset email...');
      await context.read<AuthService>().sendPasswordResetEmail(
            email: _emailController.text.trim(),
          );

      debugPrint('✅ ForgotPasswordPage - Password reset email sent successfully');

      if (mounted) {
        setState(() {
          _emailSent = true;
          _message = 'Password reset email sent! Please check your inbox and follow the instructions to reset your password.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ ForgotPasswordPage - Password reset failed: $e');
      if (mounted) {
        setState(() {
          _error = _getErrorMessage(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String error) {
    debugPrint('🔍 ForgotPasswordPage - Parsing error: $error');

    if (error.contains('user-not-found') || error.contains('auth/user-not-found')) {
      return 'No account found with this email address.';
    } else if (error.contains('invalid-email') || error.contains('auth/invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('too-many-requests') || error.contains('auth/too-many-requests')) {
      return 'Too many requests. Please try again later.';
    } else if (error.contains('network-request-failed') || error.contains('auth/network-request-failed')) {
      return 'Network error. Please check your connection and try again.';
    } else if (error.contains('auth/missing-email')) {
      return 'Please enter your email address.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  void _goBackToSignIn() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Back Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      LoggerService.info('🔥 Back button clicked!');
                      Navigator.pop(context);
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo/Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.goldColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.lock_reset,
                          size: 40,
                          color: AppTheme.goldColor,
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 32),

                      // Reset Password Card
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: AppTheme.cardDecoration,
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _emailSent ? 'Email Sent!' : 'Reset Password',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _emailSent
                                  ? 'Check your email for reset instructions'
                                  : 'Enter your email to receive reset instructions',
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            if (!_emailSent) ...[
                              // Reset Password Form
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: AppTheme.textFieldDecoration.copyWith(
                                        labelText: 'Email',
                                        hintText: 'name@example.com',
                                        prefixIcon: const Icon(
                                          Icons.email_outlined,
                                          color: AppTheme.goldColor,
                                        ),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.done,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your email';
                                        }
                                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                          return 'Please enter a valid email';
                                        }
                                        return null;
                                      },
                                      style: const TextStyle(color: Colors.white),
                                      cursorColor: AppTheme.goldColor,
                                      cursorWidth: 2.0,
                                      onFieldSubmitted: (_) => _handlePasswordReset(),
                                    ),
                                    const SizedBox(height: 24),

                                    // Send Reset Email Button
                                    ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _handlePasswordReset,
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.send),
                                      label: Text(
                                        _isLoading ? 'Sending...' : 'Send Reset Email',
                                      ),
                                      style: AppTheme.primaryButtonStyle,
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Success State
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Reset email sent to ${_emailController.text}',
                                        style: const TextStyle(color: Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Back to Sign In Button
                              ElevatedButton.icon(
                                onPressed: _goBackToSignIn,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back to Sign In'),
                                style: AppTheme.primaryButtonStyle,
                              ),
                            ],

                            // Error Message
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error,
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Success Message
                            if (_message.isNotEmpty && !_emailSent) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _message,
                                        style: const TextStyle(color: Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (!_emailSent) ...[
                              const SizedBox(height: 24),
                              // Back to Sign In Link
                              TextButton(
                                onPressed: _goBackToSignIn,
                                child: const Text(
                                  'Back to Sign In',
                                  style: TextStyle(color: AppTheme.goldColor),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ).animate().slideY(
                        begin: 0.3,
                        duration: 600.ms,
                        curve: Curves.easeOutCubic,
                      ).fadeIn(duration: 600.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
