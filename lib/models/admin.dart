class Admin {
  final String? id;
  final DateTime? createdDate;
  final DateTime? updatedDate;
  final String? createdBy;
  final String email;
  final String name;
  final String role; // Always 'super_admin' now
  final bool isActive;
  final DateTime? lastLogin;
  final String? profileImageUrl;

  Admin({
    this.id,
    this.createdDate,
    this.updatedDate,
    this.createdBy,
    required this.email,
    required this.name,
    this.role = 'super_admin',
    this.isActive = true,
    this.lastLogin,
    this.profileImageUrl,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'],
      createdDate: json['created_date'] != null
          ? DateTime.parse(json['created_date'])
          : null,
      updatedDate: json['updated_date'] != null
          ? DateTime.parse(json['updated_date'])
          : null,
      createdBy: json['created_by'],
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'super_admin',
      isActive: json['is_active'] ?? true,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
      profileImageUrl: json['profileImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_date': createdDate?.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
      'created_by': createdBy,
      'email': email,
      'name': name,
      'role': role,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'profileImageUrl': profileImageUrl,
    };
  }

  Admin copyWith({
    String? id,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? createdBy,
    String? email,
    String? name,
    String? role,
    bool? isActive,
    DateTime? lastLogin,
  }) {
    return Admin(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      createdBy: createdBy ?? this.createdBy,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  // All super admins have all permissions
  bool hasPermission(String permission) {
    return true; // Super admin has all permissions
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isModerator => role == 'moderator' || isAdmin;
}
