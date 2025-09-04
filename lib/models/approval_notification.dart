

class ApprovalNotificationModel {
  final String id;
  final String userId; // User who should receive the notification
  final String type; // 'approval_sent', 'approval_approved', 'approval_rejected'
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? eventId; // Related event ID
  final String? eventTitle; // Event title for display
  final String? eventDescription; // Event description
  final DateTime? eventDate; // Event date
  final String? eventLocation; // Event location
  final String? fromUserId; // User who triggered the notification
  final String? fromUserName; // Name of user who triggered the notification
  final String? fromUserEmail; // Email of user who triggered the notification
  final String? approvalStatus; // 'pending', 'approved', 'rejected'
  final Map<String, dynamic>? eventDetails; // Additional event details

  ApprovalNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.eventId,
    this.eventTitle,
    this.eventDescription,
    this.eventDate,
    this.eventLocation,
    this.fromUserId,
    this.fromUserName,
    this.fromUserEmail,
    this.approvalStatus,
    this.eventDetails,
  });

  factory ApprovalNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return ApprovalNotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      eventId: map['eventId'],
      eventTitle: map['eventTitle'],
      eventDescription: map['eventDescription'],
      eventDate: map['eventDate']?.toDate(),
      eventLocation: map['eventLocation'],
      fromUserId: map['fromUserId'],
      fromUserName: map['fromUserName'],
      fromUserEmail: map['fromUserEmail'],
      approvalStatus: map['approvalStatus'],
      eventDetails: map['eventDetails'] != null 
          ? Map<String, dynamic>.from(map['eventDetails'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'message': message,
      'isRead': isRead,
      'createdAt': createdAt,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventDescription': eventDescription,
      'eventDate': eventDate,
      'eventLocation': eventLocation,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserEmail': fromUserEmail,
      'approvalStatus': approvalStatus,
      'eventDetails': eventDetails,
    };
  }

  ApprovalNotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    String? eventId,
    String? eventTitle,
    String? eventDescription,
    DateTime? eventDate,
    String? eventLocation,
    String? fromUserId,
    String? fromUserName,
    String? fromUserEmail,
    String? approvalStatus,
    Map<String, dynamic>? eventDetails,
  }) {
    return ApprovalNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      eventId: eventId ?? this.eventId,
      eventTitle: eventTitle ?? this.eventTitle,
      eventDescription: eventDescription ?? this.eventDescription,
      eventDate: eventDate ?? this.eventDate,
      eventLocation: eventLocation ?? this.eventLocation,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      fromUserEmail: fromUserEmail ?? this.fromUserEmail,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      eventDetails: eventDetails ?? this.eventDetails,
    );
  }

  // Helper method to get formatted event date
  String get formattedEventDate {
    if (eventDate == null) return 'No date specified';
    return '${eventDate!.day}/${eventDate!.month}/${eventDate!.year} at ${eventDate!.hour.toString().padLeft(2, '0')}:${eventDate!.minute.toString().padLeft(2, '0')}';
  }

  // Helper method to get notification icon based on type
  String get notificationIcon {
    switch (type) {
      case 'approval_sent':
        return '📤';
      case 'approval_approved':
        return '✅';
      case 'approval_rejected':
        return '❌';
      default:
        return '📋';
    }
  }

  // Helper method to get status color
  String get statusColor {
    switch (approvalStatus) {
      case 'approved':
        return 'green';
      case 'rejected':
        return 'red';
      case 'pending':
      default:
        return 'orange';
    }
  }
}