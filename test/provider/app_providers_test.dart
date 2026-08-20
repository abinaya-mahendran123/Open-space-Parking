import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_space_parking/core/services/session_service.dart';
import 'package:open_space_parking/core/services/auth_token_provider.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';

import '../helpers/auth_fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
    registerFallbackValues();
  });

  group('AuthStateNotifier', () {
    late MockAuthRepository authRepository;
    late MockSecureStorageService secureStorage;
    late ProviderContainer container;

    setUp(() {
      authRepository = MockAuthRepository();
      secureStorage = MockSecureStorageService();

      when(() => secureStorage.read(any())).thenAnswer((_) async => null);
      when(() => secureStorage.write(any(), any())).thenAnswer((_) async {});
      when(() => secureStorage.delete(any())).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => AuthStateNotifier(
              authRepository: authRepository,
              sessionService: SessionService(secureStorage),
              authTokenProvider: AuthTokenProvider(),
            ),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('initialize sets unauthenticated when no session', () async {
      await container.read(authStateProvider.notifier).initialize();

      expect(
        container.read(authStateProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('loginAppUser saves session and updates state', () async {
      final session = AuthFixtures.session(role: UserRole.landOwner);
      when(
        () => authRepository.loginAppUser(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => session);

      await container.read(authStateProvider.notifier).loginAppUser(
            email: AuthFixtures.testEmail,
            password: AuthFixtures.testPassword,
          );

      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.session?.role, UserRole.landOwner);
    });

    test('logout clears session and sets unauthenticated', () async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final session = AuthFixtures.session();
      when(
        () => authRepository.loginAppUser(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => session);

      await container.read(authStateProvider.notifier).loginAppUser(
            email: AuthFixtures.testEmail,
            password: AuthFixtures.testPassword,
          );

      clearInteractions(secureStorage);

      await container.read(authStateProvider.notifier).logout();

      expect(
        container.read(authStateProvider).status,
        AuthStatus.unauthenticated,
      );
      verify(() => secureStorage.delete('auth_session')).called(1);
    });

    test('register uses selected role from state', () async {
      container.read(authStateProvider.notifier).setSelectedRole(
            UserRole.landOwner,
          );

      when(
        () => authRepository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
          role: UserRole.landOwner,
        ),
      ).thenAnswer(
        (_) async => AuthFixtures.session(role: UserRole.landOwner),
      );

      await container.read(authStateProvider.notifier).register(
            email: 'new@test.com',
            password: AuthFixtures.testPassword,
            displayName: 'New Owner',
          );

      verify(
        () => authRepository.register(
          email: 'new@test.com',
          password: AuthFixtures.testPassword,
          displayName: 'New Owner',
          role: UserRole.landOwner,
        ),
      ).called(1);
    });
  });

  group('notificationHistoryProvider', () {
    late MockNotificationRepository notificationRepository;
    late ProviderContainer container;

    setUp(() {
      notificationRepository = MockNotificationRepository();
      container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(
            notificationRepository,
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('returns notifications for recipient', () async {
      final notifications = [
        AppNotification(
          id: '1',
          recipientId: 'user-1',
          recipientType: NotificationRecipientType.vehicleOwner,
          title: 'Booking',
          message: 'Confirmed',
          createdAt: DateTime.utc(2026, 8, 7),
        ),
      ];

      when(
        () => notificationRepository.getHistory(
          recipientId: 'user-1',
          recipientType: NotificationRecipientType.vehicleOwner,
        ),
      ).thenAnswer((_) async => notifications);

      final result = await container.read(
        notificationHistoryProvider(
          const NotificationHistoryQuery(
            recipientId: 'user-1',
            recipientType: NotificationRecipientType.vehicleOwner,
          ),
        ).future,
      );

      expect(result, notifications);
    });
  });
}
