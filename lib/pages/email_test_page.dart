import 'package:flutter/material.dart';
import 'package:new_flutter/services/email_service.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/widgets/app_layout.dart';

class EmailTestPage extends StatefulWidget {
  const EmailTestPage({super.key});

  @override
  State<EmailTestPage> createState() => _EmailTestPageState();
}

class _EmailTestPageState extends State<EmailTestPage> {
  final _modelEmailController = TextEditingController();
  final _commentTestController = TextEditingController();
  bool _isTestingModel = false;
  bool _isTestingComment = false;
  bool _isTestingConfig = false;

  @override
  void dispose() {
    _modelEmailController.dispose();
    _commentTestController.dispose();
    super.dispose();
  }

  Future<void> _testModelInvitation() async {
    if (_modelEmailController.text.trim().isEmpty) {
      _showSnackBar('Please enter a model email address', Colors.red);
      return;
    }

    setState(() {
      _isTestingModel = true;
    });

    final currentContext = context;

    try {
      final success = await EmailService.sendModelInvitation(
        modelEmail: _modelEmailController.text.trim(),
        agentEmail: 'test@agent.com',
        agentName: 'Test Agent',
      );

      if (currentContext.mounted) {
        _showSnackBar(
          success
              ? 'Model invitation sent successfully!'
              : 'Failed to send model invitation',
          success ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (currentContext.mounted) {
        _showSnackBar('Error: $e', Colors.red);
      }
    } finally {
      if (currentContext.mounted) {
        setState(() {
          _isTestingModel = false;
        });
      }
    }
  }

  Future<void> _testCommentNotification() async {
    if (_commentTestController.text.trim().isEmpty) {
      _showSnackBar(
          'Please enter an email address for comment test', Colors.red);
      return;
    }

    setState(() {
      _isTestingComment = true;
    });

    final currentContext = context;

    try {
      final success = await EmailService.sendCommentNotification(
        postAuthorEmail: _commentTestController.text.trim(),
        postTitle: 'Test Post Title',
        commenterName: 'Test Commenter',
        commentContent:
            'This is a test comment to verify email notifications work correctly.',
        postId: 'test-post-123',
      );

      if (currentContext.mounted) {
        _showSnackBar(
          success
              ? 'Comment notification sent successfully!'
              : 'Failed to send comment notification',
          success ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (currentContext.mounted) {
        _showSnackBar('Error: $e', Colors.red);
      }
    } finally {
      if (currentContext.mounted) {
        setState(() {
          _isTestingComment = false;
        });
      }
    }
  }

  Future<void> _testEmailConfiguration() async {
    setState(() {
      _isTestingConfig = true;
    });

    final currentContext = context;

    try {
      final success = await EmailService.testEmailConfiguration();

      if (currentContext.mounted) {
        _showSnackBar(
          success
              ? 'Email configuration test successful!'
              : 'Email configuration test failed',
          success ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (currentContext.mounted) {
        _showSnackBar('Error: $e', Colors.red);
      }
    } finally {
      if (currentContext.mounted) {
        setState(() {
          _isTestingConfig = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/email-test',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Email Service Test',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.backgroundColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Configuration Test
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.goldColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email Configuration Test',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Test if SMTP configuration is working correctly',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isTestingConfig ? null : _testEmailConfiguration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isTestingConfig
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                ),
                              )
                            : const Text(
                                'Test Email Configuration',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Model Invitation Test
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Color.lerp(
                          Colors.transparent, AppTheme.goldColor, 0.3)!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Model Invitation Test',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Test sending invitation email to a model',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _modelEmailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Model Email Address',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Enter model email to test invitation',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.goldColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isTestingModel ? null : _testModelInvitation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isTestingModel
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                ),
                              )
                            : const Text(
                                'Send Test Invitation',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Comment Notification Test
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Color.lerp(
                          Colors.transparent, AppTheme.goldColor, 0.3)!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comment Notification Test',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Test sending comment notification email',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _commentTestController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Post Author Email',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Enter email to test comment notification',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.goldColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isTestingComment ? null : _testCommentNotification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isTestingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                ),
                              )
                            : const Text(
                                'Send Test Comment Notification',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
