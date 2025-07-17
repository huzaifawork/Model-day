import 'package:flutter/material.dart';
import '../../models/admin_stats.dart';
import '../../theme/app_theme.dart';

class RecentActivityCard extends StatelessWidget {
  final RecentActivity activity;

  const RecentActivityCard({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          // Activity icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getActivityColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getActivityIcon(),
              color: _getActivityColor(),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          
          // Activity details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (activity.userEmail != null) ...[
                      Text(
                        'From: ${activity.userEmail}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '•',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      activity.timeAgo,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon() {
    switch (activity.type) {
      case 'user_registered':
        return Icons.person_add;
      case 'support_message':
        return Icons.support_agent;
      case 'job_created':
        return Icons.work;
      case 'casting_created':
        return Icons.movie;
      case 'admin_login':
        return Icons.login;
      case 'admin_logout':
        return Icons.logout;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor() {
    switch (activity.type) {
      case 'user_registered':
        return AppTheme.successColor;
      case 'support_message':
        return AppTheme.warningColor;
      case 'job_created':
      case 'casting_created':
        return AppTheme.goldColor;
      case 'admin_login':
        return AppTheme.successColor;
      case 'admin_logout':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }
}
