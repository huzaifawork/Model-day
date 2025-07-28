import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';

class UserCard extends StatefulWidget {
  final User user;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onDelete;

  const UserCard({
    super.key,
    required this.user,
    this.onToggleStatus,
    this.onDelete,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.borderColor),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: widget.user.isActive ? AppTheme.goldColor : AppTheme.textMuted,
                  child: widget.user.photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            widget.user.photoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                widget.user.initials,
                                style: TextStyle(
                                  color: widget.user.isActive ? Colors.black : AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        )
                      : Text(
                          widget.user.initials,
                          style: TextStyle(
                            color: widget.user.isActive ? Colors.black : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 16),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.displayNameOrEmail,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.user.isActive ? AppTheme.successColor : AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    widget.user.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Expand icon
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),

            // Expanded content
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User details
                    const Text(
                      'User Details',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Name', widget.user.displayNameOrEmail),
                    _buildDetailRow('Email', widget.user.email),
                    _buildPasswordRow(),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        if (widget.onToggleStatus != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.onToggleStatus,
                              icon: Icon(
                                widget.user.isActive ? Icons.block : Icons.check_circle,
                                size: 16,
                              ),
                              label: Text(
                                widget.user.isActive ? 'Deactivate' : 'Activate',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.user.isActive
                                    ? AppTheme.errorColor
                                    : AppTheme.successColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        if (widget.onToggleStatus != null && widget.onDelete != null)
                          const SizedBox(width: 8),
                        if (widget.onDelete != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onDelete,
                              icon: const Icon(Icons.delete, size: 16, color: AppTheme.errorColor),
                              label: const Text(
                                'Delete',
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.errorColor),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              'Password:',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Text(
                  '••••••••',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showPasswordOptions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.goldColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Manage',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPasswordOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Password Management',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage password for ${widget.user.displayNameOrEmail}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Reset Password Option
            ListTile(
              leading: const Icon(Icons.email, color: AppTheme.goldColor),
              title: const Text(
                'Send Password Reset Email',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              subtitle: const Text(
                'User will receive an email to reset their password',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _sendPasswordResetEmail();
              },
            ),

            const Divider(color: AppTheme.borderColor),

            // Set New Password Option
            ListTile(
              leading: const Icon(Icons.lock_reset, color: AppTheme.goldColor),
              title: const Text(
                'Set New Password',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              subtitle: const Text(
                'Set a new temporary password for the user',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSetPasswordDialog();
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _sendPasswordResetEmail() async {
    try {
      await UserService.sendPasswordResetEmail(widget.user.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${widget.user.email}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send password reset email: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showSetPasswordDialog() {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text(
            'Set New Password',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a new password for ${widget.user.displayNameOrEmail}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.goldColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome, color: AppTheme.goldColor),
                        onPressed: () {
                          final newPassword = _generateRandomPassword();
                          passwordController.text = newPassword;
                        },
                        tooltip: 'Generate Random Password',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Password should be at least 6 characters long',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.length >= 6) {
                  Navigator.pop(context);
                  _setNewPassword(passwordController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters long'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Set Password'),
            ),
          ],
        ),
      ),
    );
  }

  String _generateRandomPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    String password = '';
    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }
    return password;
  }

  void _setNewPassword(String newPassword) async {
    try {
      await UserService.setUserPassword(widget.user.id!, newPassword);

      if (mounted) {
        // Show success with option to copy password
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text(
              'Password Set Successfully',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New password for ${widget.user.displayNameOrEmail}:',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          newPassword,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: AppTheme.goldColor),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: newPassword));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password copied to clipboard'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        },
                        tooltip: 'Copy Password',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Make sure to share this password securely with the user.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldColor,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set password: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
