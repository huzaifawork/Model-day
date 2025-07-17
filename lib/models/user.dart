class User {
  final String? id;
  final DateTime? createdDate;
  final DateTime? updatedDate;
  final String email;
  final String? name;
  final String? displayName;
  final String? photoUrl;
  final String? phone;
  final bool isActive;
  final DateTime? lastLogin;
  final bool emailVerified;
  final Map<String, dynamic>? profile;

  User({
    this.id,
    this.createdDate,
    this.updatedDate,
    required this.email,
    this.name,
    this.displayName,
    this.photoUrl,
    this.phone,
    this.isActive = true,
    this.lastLogin,
    this.emailVerified = false,
    this.profile,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      createdDate: json['created_date'] != null
          ? DateTime.parse(json['created_date'])
          : null,
      updatedDate: json['updated_date'] != null
          ? DateTime.parse(json['updated_date'])
          : null,
      email: json['email'] ?? '',
      name: json['name'],
      displayName: json['display_name'] ?? json['displayName'],
      photoUrl: json['photo_url'] ?? json['photoURL'],
      phone: json['phone'],
      isActive: json['is_active'] ?? true,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
      emailVerified: json['email_verified'] ?? false,
      profile: json['profile'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_date': createdDate?.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
      'email': email,
      'name': name,
      'display_name': displayName,
      'photo_url': photoUrl,
      'phone': phone,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'email_verified': emailVerified,
      'profile': profile,
    };
  }

  User copyWith({
    String? id,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? email,
    String? name,
    String? displayName,
    String? photoUrl,
    String? phone,
    bool? isActive,
    DateTime? lastLogin,
    bool? emailVerified,
    Map<String, dynamic>? profile,
  }) {
    return User(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      email: email ?? this.email,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      emailVerified: emailVerified ?? this.emailVerified,
      profile: profile ?? this.profile,
    );
  }

  String get displayNameOrEmail => displayName ?? name ?? email;
  
  String get initials {
    final displayName = this.displayName ?? name ?? email;
    if (displayName.isEmpty) return '?';
    
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return displayName[0].toUpperCase();
    }
  }
}
