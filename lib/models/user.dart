// lib/models/user.dart

import '../core/utils/url_helper.dart';

class User {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final bool isVerified;
  final String? avatarUrl;
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isVerified,
    this.avatarUrl,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? json['Id']?.toString() ?? '',
      fullName: json['fullName'] ?? json['FullName'] ?? '',
      email: json['email'] ?? json['Email'] ?? '',
      phone: json['phone'] ?? json['Phone'] ?? '',
      role: json['role'] ?? json['Role'] ?? 'tenant',
      isVerified: json['isVerified'] ?? json['IsVerified'] ?? false,
      avatarUrl: UrlHelper.sanitizeUrl(json['avatarUrl'] ?? json['AvatarUrl']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['CreatedAt'] != null
              ? DateTime.parse(json['CreatedAt'])
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'isVerified': isVerified,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
