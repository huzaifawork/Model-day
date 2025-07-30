import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/app_layout.dart';
import '../widgets/support_map.dart';
import '../widgets/ui/input.dart' as ui;
import '../services/support_service.dart';
import '../services/auth_service.dart';
import '../models/support_message.dart';
import '../theme/app_theme.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  List<SupportMessage> _userMessages = [];
  bool _isLoadingMessages = false;

  @override
  void initState() {
    super.initState();
    _loadUserMessages();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserMessages() async {
    setState(() {
      _isLoadingMessages = true;
    });

    try {
      final messages = await SupportService.getUserSupportMessages();
      if (mounted) {
        setState(() {
          _userMessages = messages;
          _isLoadingMessages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  Future<void> _submitSupportMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final result = await SupportService.submitSupportMessage(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        userEmail: currentUser.email ?? '',
        userId: currentUser.uid,
      );

      if (result != null) {
        _titleController.clear();
        _messageController.clear();

        // Reload user messages to show the new message
        _loadUserMessages();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Support message submitted successfully! We\'ll get back to you soon.'),
              backgroundColor: AppTheme.goldColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('Failed to submit support message');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/support',
      title: 'Support',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Get Support',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.goldColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re here to help! Find our location, send us a message, or check out our resources.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Map Section
            _buildMapSection(),
            const SizedBox(height: 32),

            // Support Message Section
            _buildSupportMessageSection(),
            const SizedBox(height: 32),

            // My Support Messages Section
            _buildMyMessagesSection(),
            const SizedBox(height: 32),

            // External Links Section
            _buildExternalLinksSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.goldColor),
                const SizedBox(width: 8),
                const Text(
                  'Our Location',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SupportMap(),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportMessageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.message, color: AppTheme.goldColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Send Support Message',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ui.Input(
                label: 'Subject',
                controller: _titleController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ui.Input(
                label: 'Message',
                controller: _messageController,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your message';
                  }
                  if (value.trim().length < 10) {
                    return 'Message must be at least 10 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSupportMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'Submit Message',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExternalLinksSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: AppTheme.goldColor),
                const SizedBox(width: 8),
                const Text(
                  'External Links',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialMediaButton(
                  icon: FontAwesomeIcons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  url: 'https://facebook.com/modelday',
                ),
                _buildSocialMediaButton(
                  icon: FontAwesomeIcons.whatsapp,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  url: 'https://wa.me/1234567890',
                ),
                _buildSocialMediaButton(
                  icon: FontAwesomeIcons.instagram,
                  label: 'Instagram',
                  color: const Color(0xFFE4405F),
                  url: 'https://instagram.com/modelday',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required String url,
    String? assetPath,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => _launchUrl(url),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: _buildSocialIcon(icon, color, assetPath),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildMyMessagesSection() {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppTheme.goldColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'My Support Messages',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: IconButton(
                    onPressed: _loadUserMessages,
                    icon: const Icon(Icons.refresh,
                        color: AppTheme.goldColor, size: 20),
                    tooltip: 'Refresh Messages',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingMessages)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.goldColor),
              )
            else if (_userMessages.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                      color: AppTheme.borderColor.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: AppTheme.textMuted,
                    ),
                    SizedBox(height: AppTheme.spacingSm),
                    Text(
                      'No support messages yet',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _userMessages
                    .map((message) => _buildMessageCard(message))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(SupportMessage message) {
    final hasResponse =
        message.adminResponse != null && message.adminResponse!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMd),
                topRight: Radius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Submitted on ${_formatDate(message.createdAt)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(message.status),
              ],
            ),
          ),

          // Message content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Message:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message.message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),

                // Admin response section
                if (hasResponse) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings,
                        color: AppTheme.goldColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Admin Response:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.goldColor,
                        ),
                      ),
                      if (message.updatedAt != null) ...[
                        const Spacer(),
                        Text(
                          _formatDate(message.updatedAt!),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.goldColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: AppTheme.goldColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      message.adminResponse!,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        displayText = 'Pending';
        break;
      case 'resolved':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        displayText = 'Resolved';
        break;
      case 'closed':
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        displayText = 'Closed';
        break;
      default:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSocialIcon(IconData icon, Color color, String? assetPath) {
    // Try to use PNG asset first, fallback to FontAwesome icon
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: 28,
        height: 28,
        color: color,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to FontAwesome icon if PNG fails to load
          return FaIcon(
            icon,
            color: color,
            size: 28,
          );
        },
      );
    } else {
      return FaIcon(
        icon,
        color: color,
        size: 28,
      );
    }
  }
}
