import 'package:equatable/equatable.dart';

import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.jwtToken,
    required this.expiresAt,
    this.phone = '',
  });

  final String userId;
  final String email;
  final String displayName;
  final UserRole role;
  final String jwtToken;
  final DateTime expiresAt;
  final String phone;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get greetingName {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    final realEmail = ProfilePrefill.realEmail(email);
    if (realEmail != null && realEmail.contains('@')) {
      return realEmail.split('@').first;
    }
    return 'User';
  }

  /// Email safe for UI — never returns synthetic system addresses.
  String get displayEmail => ProfilePrefill.realEmail(email) ?? '';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'role': role.value,
        'jwtToken': jwtToken,
        'expiresAt': expiresAt.toIso8601String(),
        'phone': phone,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['userId'] as String,
      email: ProfilePrefill.realEmail(json['email'] as String?) ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: UserRoleX.fromValue(json['role'] as String),
      jwtToken: json['jwtToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      phone: (json['phone'] as String?)?.trim() ?? '',
    );
  }

  @override
  List<Object?> get props =>
      [userId, email, displayName, role, jwtToken, expiresAt, phone];
}
