class NotificationModel {
  final String id;
  final String userId; // User who should receive the notification
  final String type; // 'comment', 'like', 'post', etc.
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? postId; // Related post ID
  final String? commentId; // Related comment ID
  final String? fromUserId; // User who triggered the notification
  final String? fromUserName; // Name of user who triggered the notification

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.postId,
    this.commentId,
    this.fromUserId,
    this.fromUserName,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      postId: map['postId'],
      commentId: map['commentId'],
      fromUserId: map['fromUserId'],
      fromUserName: map['fromUserName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'message': message,
      'isRead': isRead,
      'createdAt': createdAt,
      'postId': postId,
      'commentId': commentId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    String? postId,
    String? commentId,
    String? fromUserId,
    String? fromUserName,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
    );
  }
}