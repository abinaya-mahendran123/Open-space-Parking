import 'package:flutter_test/flutter_test.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

void main() {
  group('AuthSession', () {
    test('serializes and deserializes to JSON', () {
      final session = AuthSession(
        userId: 'abc123',
        email: 'user@test.com',
        displayName: 'Test User',
        role: UserRole.landOwner,
        jwtToken: 'jwt.token.here',
        expiresAt: DateTime.utc(2026, 12, 31),
      );

      final restored = AuthSession.fromJson(session.toJson());

      expect(restored.userId, session.userId);
      expect(restored.email, session.email);
      expect(restored.displayName, session.displayName);
      expect(restored.role, session.role);
      expect(restored.jwtToken, session.jwtToken);
      expect(restored.expiresAt, session.expiresAt);
    });

    test('isExpired returns true for past expiry', () {
      final session = AuthSession(
        userId: '1',
        email: 'a@b.com',
        displayName: 'User',
        role: UserRole.vehicleOwner,
        jwtToken: 't',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(session.isExpired, isTrue);
    });

    test('isExpired returns false for future expiry', () {
      final session = AuthSession(
        userId: '1',
        email: 'a@b.com',
        displayName: 'User',
        role: UserRole.vehicleOwner,
        jwtToken: 't',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      expect(session.isExpired, isFalse);
    });

    test('greetingName prefers displayName over email prefix', () {
      final session = AuthSession(
        userId: '1',
        email: 'aasin12@gmail.com',
        displayName: 'Aasin Kumar',
        role: UserRole.landOwner,
        jwtToken: 't',
        expiresAt: DateTime.utc(2026, 1, 1),
      );

      expect(session.greetingName, 'Aasin Kumar');
    });

    test('greetingName falls back to email prefix when displayName empty', () {
      final session = AuthSession(
        userId: '1',
        email: 'aasin12@gmail.com',
        displayName: '',
        role: UserRole.landOwner,
        jwtToken: 't',
        expiresAt: DateTime.utc(2026, 1, 1),
      );

      expect(session.greetingName, 'aasin12');
    });

    test('equatable compares by value', () {
      final a = AuthSession(
        userId: '1',
        email: 'a@b.com',
        displayName: 'User',
        role: UserRole.vehicleOwner,
        jwtToken: 't',
        expiresAt: DateTime.utc(2026, 1, 1),
      );
      final b = AuthSession(
        userId: '1',
        email: 'a@b.com',
        displayName: 'User',
        role: UserRole.vehicleOwner,
        jwtToken: 't',
        expiresAt: DateTime.utc(2026, 1, 1),
      );

      expect(a, equals(b));
    });
  });
}
