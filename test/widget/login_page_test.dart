import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:mocktail/mocktail.dart';

import 'package:open_space_parking/core/providers/core_providers.dart';

import 'package:open_space_parking/core/services/session_service.dart';
import 'package:open_space_parking/core/services/auth_token_provider.dart';

import 'package:open_space_parking/core/services/snackbar_service.dart';

import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

import 'package:open_space_parking/features/authentication/presentation/pages/auth_page.dart';

import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';

import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';

import 'package:open_space_parking/features/authentication/presentation/widgets/auth_scaffold.dart';

import '../helpers/auth_fixtures.dart';

import '../helpers/mocks.dart';

import '../helpers/pump_app.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
    registerFallbackValues();
  });

  group('AuthPage', () {
    late MockAuthRepository authRepository;
    late MockSecureStorageService secureStorage;

    setUp(() {
      authRepository = MockAuthRepository();
      secureStorage = MockSecureStorageService();

      when(() => secureStorage.read(any())).thenAnswer((_) async => null);
      when(() => secureStorage.write(any(), any())).thenAnswer((_) async {});
      when(() => secureStorage.delete(any())).thenAnswer((_) async {});
    });

    Widget buildAuthPage() {
      return ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => AuthStateNotifier(
              authRepository: authRepository,
              sessionService: SessionService(secureStorage),
              authTokenProvider: AuthTokenProvider(),
            ),
          ),
          authLoadingProvider.overrideWith((ref) => false),
          authFormModeProvider.overrideWith((ref) => AuthFormMode.signIn),
          phoneAuthStepProvider.overrideWith((ref) => PhoneAuthStep.enterPhone),
          snackbarServiceProvider.overrideWithValue(SnackbarService()),
        ],
        child: const MaterialApp(home: AuthPage()),
      );
    }

    testWidgets('renders sign-in method pill buttons', (tester) async {
      await tester.pumpWidget(buildAuthPage());
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Sign in with phone number'), findsOneWidget);
      expect(find.text('Sign in with email'), findsOneWidget);
    });

    testWidgets('opens phone flow from pill button', (tester) async {
      await tester.pumpWidget(buildAuthPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with phone number'));
      await tester.pumpAndSettle();

      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
    });

    testWidgets('opens email flow and validates empty form', (tester) async {
      await tester.pumpWidget(buildAuthPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with email'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('calls loginAppUser from email flow', (tester) async {
      when(
        () => authRepository.loginAppUser(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => AuthFixtures.session(role: UserRole.vehicleOwner),
      );

      await tester.pumpWidget(buildAuthPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with email'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), AuthFixtures.testEmail);
      await tester.enterText(
        find.byType(TextFormField).at(1),
        AuthFixtures.testPassword,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      verify(
        () => authRepository.loginAppUser(
          email: AuthFixtures.testEmail,
          password: AuthFixtures.testPassword,
        ),
      ).called(1);
    });
  });

  group('AuthScaffold', () {
    testWidgets('renders title and child content', (tester) async {
      await pumpAppWidget(
        tester,
        const AuthScaffold(
          title: 'Sign In',
          child: Text('Form content'),
        ),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Form content'), findsOneWidget);
    });
  });
}
