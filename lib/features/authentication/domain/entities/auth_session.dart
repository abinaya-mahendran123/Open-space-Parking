import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.jwtToken,
    required this.expiresAt,
  });

  final String userId;
  final String email;
  final String displayName;
  final UserRole role;
  final String jwtToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get greetingName {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    return email.split('@').first;
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'role': role.value,
        'jwtToken': jwtToken,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['userId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? '',
      role: UserRoleX.fromValue(json['role'] as String),
      jwtToken: json['jwtToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  @override
  List<Object?> get props => [userId, email, displayName, role, jwtToken, expiresAt];
}
