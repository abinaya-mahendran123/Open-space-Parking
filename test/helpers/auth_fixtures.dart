import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

class AuthFixtures {
  AuthFixtures._();

  static const testPassword = 'password123';
  static const testEmail = 'owner@test.com';
  static const testSalt = 'fixed-test-salt';

  static String passwordHash(String password, {String salt = testSalt}) {
    return sha256.convert(utf8.encode('$password::$salt')).toString();
  }

  static Map<String, dynamic> userDocument({
    String email = testEmail,
    UserRole role = UserRole.vehicleOwner,
    String password = testPassword,
    String salt = testSalt,
    ObjectId? id,
  }) {
    return {
      '_id': id ?? ObjectId(),
      'email': email.trim().toLowerCase(),
      'role': role.value,
      'passwordSalt': salt,
      'passwordHash': passwordHash(password, salt: salt),
      'displayName': 'Test User',
    };
  }

  static Map<String, dynamic> employeeDocument({
    String email = 'employee@test.com',
    String phone = '9876543210',
    String? password,
    String salt = testSalt,
    bool isActive = true,
    ObjectId? id,
  }) {
    // Default employee password = last 6 digits of phone.
    final resolvedPassword = password ??
        (phone.replaceAll(RegExp(r'\D'), '').length >= 6
            ? phone.replaceAll(RegExp(r'\D'), '').substring(
                  phone.replaceAll(RegExp(r'\D'), '').length - 6,
                )
            : '000000');
    return {
      '_id': id ?? ObjectId(),
      'email': email.trim().toLowerCase(),
      'phone': phone,
      'fullName': 'Test Employee',
      'isActive': isActive,
      'passwordSalt': salt,
      'passwordHash': passwordHash(resolvedPassword, salt: salt),
    };
  }

  static AuthSession session({
    String userId = 'user-123',
    String email = testEmail,
    String displayName = 'Test User',
    UserRole role = UserRole.vehicleOwner,
  }) {
    final issuedAt = DateTime.now().toUtc();
    return AuthSession(
      userId: userId,
      email: email,
      displayName: displayName,
      role: role,
      jwtToken: 'test.jwt.token',
      expiresAt: issuedAt.add(const Duration(days: 7)),
    );
  }
}
