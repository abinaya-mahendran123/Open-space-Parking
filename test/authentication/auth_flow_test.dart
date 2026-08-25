import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/auth_token_provider.dart';
import 'package:open_space_parking/core/services/session_service.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';

import '../helpers/auth_fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

/// End-to-end authentication behavior tests (not UI).
void main() {
  setUpAll(() async {
    await initTestEnvironment();
    registerFallbackValues();
  });

  group('Authentication flows', () {
    late MockAuthRepository authRepository;
    late MockSecureStorageService secureStorage;
    late AuthStateNotifier notifier;

    setUp(() {
      authRepository = MockAuthRepository();
      secureStorage = MockSecureStorageService();

      when(() => secureStorage.read(any())).thenAnswer((_) async => null);
      when(() => secureStorage.write(any(), any())).thenAnswer((_) async {});
      when(() => secureStorage.delete(any())).thenAnswer((_) async {});
    });

    Future<AuthStateNotifier> createNotifier() async {
      final notifier = AuthStateNotifier(
        authRepository: authRepository,
        sessionService: SessionService(secureStorage),
        authTokenProvider: AuthTokenProvider(),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return notifier;
    }

    test('vehicle owner can login via app portal', () async {
      notifier = await createNotifier();
      when(
        () => authRepository.loginAppUser(
          email: AuthFixtures.testEmail,
          password: AuthFixtures.testPassword,
        ),
      ).thenAnswer(
        (_) async => AuthFixtures.session(role: UserRole.vehicleOwner),
      );

      await notifier.loginAppUser(
        email: AuthFixtures.testEmail,
        password: AuthFixtures.testPassword,
      );

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.session?.role, UserRole.vehicleOwner);
    });

    test('land owner registration saves account without session', () async {
      notifier = await createNotifier();

      when(
        () => authRepository.register(
          email: 'owner@test.com',
          password: AuthFixtures.testPassword,
          displayName: 'Land Owner',
          role: UserRole.landOwner,
        ),
      ).thenAnswer(
        (_) async => AuthFixtures.session(
          email: 'owner@test.com',
          role: UserRole.landOwner,
        ),
      );

      await notifier.registerAccount(
        email: 'owner@test.com',
        password: AuthFixtures.testPassword,
        displayName: 'Land Owner',
        role: UserRole.landOwner,
      );

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.selectedRole, UserRole.landOwner);
      verify(
        () => authRepository.register(
          email: 'owner@test.com',
          password: AuthFixtures.testPassword,
          displayName: 'Land Owner',
          role: UserRole.landOwner,
        ),
      ).called(1);
    });

    test('admin login uses dedicated repository method', () async {
      notifier = await createNotifier();
      when(
        () => authRepository.loginAdmin(
          email: 'admin@test.com',
          password: AuthFixtures.testPassword,
        ),
      ).thenAnswer(
        (_) async => AuthFixtures.session(
          email: 'admin@test.com',
          role: UserRole.admin,
        ),
      );

      await notifier.loginAdmin(
        email: 'admin@test.com',
        password: AuthFixtures.testPassword,
      );

      expect(notifier.state.session?.role, UserRole.admin);
    });

    test('employee login uses employee repository method', () async {
      notifier = await createNotifier();
      when(
        () => authRepository.loginEmployee(
          phone: '9876543210',
          password: '543210',
        ),
      ).thenAnswer(
        (_) async => AuthFixtures.session(
          email: 'employee@test.com',
          role: UserRole.employee,
        ),
      );

      await notifier.loginEmployee(
        phone: '9876543210',
        password: '543210',
      );

      expect(notifier.state.session?.role, UserRole.employee);
    });

    test('restores session on initialize when valid session stored', () async {
      final session = AuthFixtures.session();
      when(() => secureStorage.read('auth_session')).thenAnswer(
        (_) async => jsonEncode(session.toJson()),
      );

      notifier = await createNotifier();

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.session?.userId, session.userId);
    });

    test('clears expired session on initialize', () async {
      final expiredSession = AuthSession(
        userId: 'user-1',
        email: AuthFixtures.testEmail,
        displayName: 'Test User',
        role: UserRole.vehicleOwner,
        jwtToken: 'token',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      when(() => secureStorage.read('auth_session')).thenAnswer(
        (_) async => jsonEncode(expiredSession.toJson()),
      );

      notifier = await createNotifier();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      verify(() => secureStorage.delete('auth_session')).called(1);
    });

    test('forgotPassword delegates to repository', () async {
      notifier = await createNotifier();
      when(
        () => authRepository.requestPasswordReset(
          email: any(named: 'email'),
        ),
      ).thenAnswer((_) async {});

      await notifier.forgotPassword(AuthFixtures.testEmail);

      verify(
        () => authRepository.requestPasswordReset(
          email: AuthFixtures.testEmail,
        ),
      ).called(1);
    });

    test('login failure does not authenticate user', () async {
      notifier = await createNotifier();
      when(
        () => authRepository.loginAppUser(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AppException('Invalid credentials.'));

      await expectLater(
        notifier.loginAppUser(
          email: AuthFixtures.testEmail,
          password: 'wrong',
        ),
        throwsA(isA<AppException>()),
      );

      expect(notifier.state.status, isNot(AuthStatus.authenticated));
    });
  });
}
