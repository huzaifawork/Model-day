class SupportMessage {
  final String id;
  final String title;
  final String message;
  final String userEmail;
  final String userId;
  final DateTime createdAt;
  final String status; // pending, resolved, closed
  final String? adminResponse;
  final String? adminId;
  final DateTime? updatedAt;

  SupportMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.userEmail,
    required this.userId,
    required this.createdAt,
    this.status = 'pending',
    this.adminResponse,
    this.adminId,
    this.updatedAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      userEmail: json['userEmail'] ?? '',
      userId: json['userId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      adminResponse: json['admin_response'],
      adminId: json['admin_id'],
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'userEmail': userEmail,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'admin_response': adminResponse,
      'admin_id': adminId,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  SupportMessage copyWith({
    String? id,
    String? title,
    String? message,
    String? userEmail,
    String? userId,
    DateTime? createdAt,
    String? status,
    String? adminResponse,
    String? adminId,
    DateTime? updatedAt,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      userEmail: userEmail ?? this.userEmail,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      adminResponse: adminResponse ?? this.adminResponse,
      adminId: adminId ?? this.adminId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
