import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:new_flutter/theme/app_theme.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.backgroundColor,
        iconTheme: const IconThemeData(color: AppTheme.goldColor),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    const Icon(
                      Icons.description,
                      size: 48,
                      color: AppTheme.goldColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Terms and Conditions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms),
              
              const SizedBox(height: 24),
              
              // Terms Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      '1. Acceptance of Terms',
                      'By accessing and using ModelDay, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
                    ),
                    
                    _buildSection(
                      '2. Service Description',
                      'ModelDay is a professional modeling career management platform that helps models track their bookings, manage relationships with agents and agencies, and organize their professional activities.',
                    ),
                    
                    _buildSection(
                      '3. User Accounts',
                      'You are responsible for safeguarding the password and for maintaining the confidentiality of your account. You agree not to disclose your password to any third party and to take sole responsibility for activities that occur under your account.',
                    ),
                    
                    _buildSection(
                      '4. Privacy and Data Protection',
                      'We are committed to protecting your privacy. Our Privacy Policy explains how we collect, use, and protect your information when you use our service. By using ModelDay, you agree to the collection and use of information in accordance with our Privacy Policy.',
                    ),
                    
                    _buildSection(
                      '5. User Content',
                      'You retain ownership of any content you submit, post, or display on or through ModelDay. By submitting content, you grant us a worldwide, non-exclusive, royalty-free license to use, copy, reproduce, process, adapt, modify, publish, transmit, display, and distribute such content.',
                    ),
                    
                    _buildSection(
                      '6. Prohibited Uses',
                      'You may not use ModelDay for any unlawful purpose or to solicit others to perform unlawful acts. You may not transmit any worms, viruses, or any code of a destructive nature. You may not attempt to gain unauthorized access to our systems.',
                    ),
                    
                    _buildSection(
                      '7. Intellectual Property',
                      'The service and its original content, features, and functionality are and will remain the exclusive property of ModelDay and its licensors. The service is protected by copyright, trademark, and other laws.',
                    ),
                    
                    _buildSection(
                      '8. Termination',
                      'We may terminate or suspend your account and bar access to the service immediately, without prior notice or liability, under our sole discretion, for any reason whatsoever, including without limitation if you breach the Terms.',
                    ),
                    
                    _buildSection(
                      '9. Disclaimer',
                      'The information on this platform is provided on an "as is" basis. To the fullest extent permitted by law, ModelDay excludes all representations, warranties, conditions, and terms whether express or implied.',
                    ),
                    
                    _buildSection(
                      '10. Limitation of Liability',
                      'In no event shall ModelDay, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses.',
                    ),
                    
                    _buildSection(
                      '11. Changes to Terms',
                      'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days notice prior to any new terms taking effect.',
                    ),
                    
                    _buildSection(
                      '12. Contact Information',
                      'If you have any questions about these Terms and Conditions, please contact us at support@modelday.app',
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
              
              const SizedBox(height: 24),
              
              // Accept Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('I Understand'),
                      style: AppTheme.primaryButtonStyle.copyWith(
                        minimumSize: WidgetStateProperty.all(
                          const Size(double.infinity, 50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Go Back',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.goldColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
