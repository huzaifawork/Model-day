class AdminStats {
  final int totalUsers;
  final int totalJobs;
  final int totalCastings;
  final int supportMessages;
  final int pendingSupportMessages;
  final int activeUsers;
  final int newUsersThisMonth;
  final int newJobsThisMonth;
  final int newCastingsThisMonth;
  final List<RecentActivity> recentActivities;

  AdminStats({
    this.totalUsers = 0,
    this.totalJobs = 0,
    this.totalCastings = 0,
    this.supportMessages = 0,
    this.pendingSupportMessages = 0,
    this.activeUsers = 0,
    this.newUsersThisMonth = 0,
    this.newJobsThisMonth = 0,
    this.newCastingsThisMonth = 0,
    this.recentActivities = const [],
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['total_users'] ?? 0,
      totalJobs: json['total_jobs'] ?? 0,
      totalCastings: json['total_castings'] ?? 0,
      supportMessages: json['support_messages'] ?? 0,
      pendingSupportMessages: json['pending_support_messages'] ?? 0,
      activeUsers: json['active_users'] ?? 0,
      newUsersThisMonth: json['new_users_this_month'] ?? 0,
      newJobsThisMonth: json['new_jobs_this_month'] ?? 0,
      newCastingsThisMonth: json['new_castings_this_month'] ?? 0,
      recentActivities: (json['recent_activities'] as List<dynamic>?)
              ?.map((activity) => RecentActivity.fromJson(activity))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_users': totalUsers,
      'total_jobs': totalJobs,
      'total_castings': totalCastings,
      'support_messages': supportMessages,
      'pending_support_messages': pendingSupportMessages,
      'active_users': activeUsers,
      'new_users_this_month': newUsersThisMonth,
      'new_jobs_this_month': newJobsThisMonth,
      'new_castings_this_month': newCastingsThisMonth,
      'recent_activities': recentActivities.map((activity) => activity.toJson()).toList(),
    };
  }
}

class RecentActivity {
  final String id;
  final String type; // 'user_registered', 'support_message', 'job_created', etc.
  final String description;
  final String? userEmail;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  RecentActivity({
    required this.id,
    required this.type,
    required this.description,
    this.userEmail,
    required this.timestamp,
    this.metadata,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      userEmail: json['user_email'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'user_email': userEmail,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
