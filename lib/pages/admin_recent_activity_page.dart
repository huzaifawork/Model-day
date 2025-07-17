import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../models/admin_stats.dart';
import '../theme/app_theme.dart';
import '../widgets/admin/admin_layout.dart';

class AdminRecentActivityPage extends StatefulWidget {
  const AdminRecentActivityPage({super.key});

  @override
  State<AdminRecentActivityPage> createState() =>
      _AdminRecentActivityPageState();
}

class _AdminRecentActivityPageState extends State<AdminRecentActivityPage> {
  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Recent Activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity list
          Expanded(
            child: StreamBuilder<List<RecentActivity>>(
              stream: AdminService.getRecentActivitiesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.goldColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading activities: ${snapshot.error}',
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final activities = snapshot.data ?? [];
                // Only show admin login and logout activities
                final filteredActivities = activities
                    .where((activity) =>
                        activity.type == 'admin_login' ||
                        activity.type == 'admin_logout')
                    .toList();

                if (filteredActivities.isEmpty) {
                  return Container(
                    decoration: AppTheme.cardDecoration,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: AppTheme.textMuted,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No activities found',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  decoration: AppTheme.cardDecoration,
                  child: ListView.builder(
                    itemCount: filteredActivities.length,
                    itemBuilder: (context, index) {
                      final activity = filteredActivities[index];
                      return _buildActivityCard(activity);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(RecentActivity activity) {
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
              color: _getActivityColor(activity.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getActivityIcon(activity.type),
              color: _getActivityColor(activity.type),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (activity.userEmail != null) ...[
                      Icon(
                        Icons.person,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          activity.userEmail!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatTimestamp(activity.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Activity type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getActivityColor(activity.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getActivityColor(activity.type).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _getActivityTypeDisplayName(activity.type),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _getActivityColor(activity.type),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActivityTypeDisplayName(String type) {
    switch (type) {
      case 'user_registered':
        return 'USER';
      case 'support_message':
        return 'SUPPORT';
      case 'job_created':
        return 'JOB';
      case 'casting_created':
        return 'CASTING';
      case 'admin_login':
        return 'ADMIN';
      case 'admin_logout':
        return 'ADMIN';
      case 'user_status_changed':
        return 'USER';
      case 'user_deleted':
        return 'USER';
      case 'password_reset_sent':
        return 'SECURITY';
      case 'password_changed':
        return 'SECURITY';
      default:
        return type.toUpperCase();
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
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
      case 'user_status_changed':
        return Icons.toggle_on;
      case 'user_deleted':
        return Icons.person_remove;
      case 'password_reset_sent':
        return Icons.email;
      case 'password_changed':
        return Icons.lock_reset;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'user_registered':
        return AppTheme.successColor;
      case 'support_message':
        return AppTheme.goldColor;
      case 'job_created':
        return Colors.blue;
      case 'casting_created':
        return Colors.purple;
      case 'admin_login':
        return AppTheme.successColor;
      case 'admin_logout':
        return AppTheme.textSecondary;
      case 'user_status_changed':
        return Colors.orange;
      case 'user_deleted':
        return AppTheme.errorColor;
      case 'password_reset_sent':
        return Colors.blue;
      case 'password_changed':
        return AppTheme.textMuted;
      default:
        return AppTheme.textMuted;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
