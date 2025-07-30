import 'package:flutter/material.dart';
import '../../models/admin.dart';
import '../../theme/app_theme.dart';

class AdminCard extends StatefulWidget {
  final Admin admin;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AdminCard({
    super.key,
    required this.admin,
    this.onToggleStatus,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<AdminCard> {
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
                  backgroundColor: widget.admin.isActive ? AppTheme.goldColor : AppTheme.textMuted,
                  child: Text(
                    widget.admin.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: widget.admin.isActive ? Colors.black : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Admin details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.admin.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor().withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getRoleColor().withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              widget.admin.role.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                color: _getRoleColor(),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.admin.email,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            widget.admin.isActive ? Icons.check_circle : Icons.cancel,
                            color: widget.admin.isActive ? AppTheme.successColor : AppTheme.errorColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.admin.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: widget.admin.isActive ? AppTheme.successColor : AppTheme.errorColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.admin.lastLogin != null) ...[
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.access_time,
                              color: AppTheme.textMuted,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Last login: ${_formatLastLogin()}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Expand/Collapse icon
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondary,
                ),

                // Actions menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  onSelected: (value) {
                    switch (value) {
                      case 'toggle_status':
                        widget.onToggleStatus?.call();
                        break;
                      case 'edit':
                        widget.onEdit?.call();
                        break;
                      case 'delete':
                        widget.onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, color: AppTheme.goldColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Edit',
                            style: TextStyle(color: AppTheme.goldColor),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            widget.admin.isActive ? Icons.block : Icons.check_circle,
                            color: widget.admin.isActive ? AppTheme.errorColor : AppTheme.successColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.admin.isActive ? 'Freeze' : 'Activate',
                            style: TextStyle(
                              color: widget.admin.isActive ? AppTheme.errorColor : AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: AppTheme.errorColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Expanded details section
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Details',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('ID', widget.admin.id ?? 'N/A'),
                    _buildDetailRow('Name', widget.admin.name),
                    _buildDetailRow('Email', widget.admin.email),
                    _buildDetailRow('Role', widget.admin.role.replaceAll('_', ' ').toUpperCase()),
                    _buildDetailRow('Status', widget.admin.isActive ? 'Active' : 'Inactive'),
                    _buildDetailRow('Created', widget.admin.createdDate != null
                        ? _formatDate(widget.admin.createdDate!) : 'N/A'),
                    _buildDetailRow('Last Login', widget.admin.lastLogin != null
                        ? _formatDate(widget.admin.lastLogin!) : 'Never'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.goldColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.goldColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: 16,
                            color: AppTheme.goldColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SUPER ADMIN - ALL PERMISSIONS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.goldColor,
                            ),
                          ),
                        ],
                      ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getRoleColor() {
    switch (widget.admin.role) {
      case 'super_admin':
        return AppTheme.goldColor;
      case 'admin':
        return AppTheme.successColor;
      case 'moderator':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatLastLogin() {
    if (widget.admin.lastLogin == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(widget.admin.lastLogin!);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
