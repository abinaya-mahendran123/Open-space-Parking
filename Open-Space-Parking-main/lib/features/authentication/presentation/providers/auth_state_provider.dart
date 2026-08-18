import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/services/api/google_auth_service.dart';
import 'package:open_space_parking/core/services/api/otp_auth_service.dart';
import 'package:open_space_parking/core/services/session_service.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/authentication/domain/repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.session, this.selectedRole});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unauthenticated({UserRole? selectedRole})
      : this(status: AuthStatus.unauthenticated, selectedRole: selectedRole);

  const AuthState.authenticated(AuthSession session)
      : this(status: AuthStatus.authenticated, session: session);

  final AuthStatus status;
  final AuthSession? session;
  final UserRole? selectedRole;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    UserRole? selectedRole,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      selectedRole: selectedRole ?? this.selectedRole,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier({
    required AuthRepository authRepository,
    required SessionService sessionService,
  })  : _authRepository = authRepository,
        _sessionService = sessionService,
        super(const AuthState.unknown()) {
    initialize();
  }

  final AuthRepository _authRepository;
  final SessionService _sessionService;

  Future<void> initialize() async {
    try {
      final session = await _sessionService.readSession();
      if (session == null || session.isExpired) {
        await _sessionService.clearSession();
        state = const AuthState.unauthenticated();
        return;
      }
      state = AuthState.authenticated(session);
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  void setSelectedRole(UserRole role) {
    state = state.copyWith(selectedRole: role);
  }

  Future<void> loginAppUser({
    required String email,
    required String password,
  }) async {
    AppException? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final session = await _authRepository.loginAppUser(
          email: email,
          password: password,
        );
        await _sessionService.saveSession(session);
        state = AuthState.authenticated(session);
        return;
      } on AppException catch (error) {
        lastError = error;
        final shouldRetry = attempt < 2 && _isTransientLoginFailure(error);
        if (!shouldRetry) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }

    throw lastError ?? const AppException('Sign in failed.');
  }

  /// Saves a new account to MongoDB without signing the user in.
  Future<void> registerAccount({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    await _authRepository.register(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
    );
    await _sessionService.clearSession();
    state = AuthState.unauthenticated(selectedRole: role);
  }

  bool _isTransientLoginFailure(AppException error) {
    final message = error.message.toLowerCase();
    return message.contains('invalid credentials') ||
        message.contains('corrupted account');
  }

  Future<void> loginAdmin({
    required String email,
    required String password,
  }) async {
    final session = await _authRepository.loginAdmin(
      email: email,
      password: password,
    );
    await _sessionService.saveSession(session);
    state = AuthState.authenticated(session);
  }

  Future<void> loginEmployee({
    required String email,
    required String password,
  }) async {
    final session = await _authRepository.loginEmployee(
      email: email,
      password: password,
    );
    await _sessionService.saveSession(session);
    state = AuthState.authenticated(session);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final role = state.selectedRole ?? UserRole.vehicleOwner;
    final session = await _authRepository.register(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
    );
    await _sessionService.saveSession(session);
    state = AuthState.authenticated(session);
  }

  Future<void> forgotPassword(String email) {
    return _authRepository.requestPasswordReset(email: email);
  }

  Future<OtpSendResult> sendPhoneOtp(String phone) {
    return sl<OtpAuthService>().sendOtp(phone);
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String otp,
    required AuthFormMode mode,
    String? displayName,
    UserRole? role,
  }) async {
    final verifiedPhone =
        await sl<OtpAuthService>().verifyOtp(phone: phone, otp: otp);

    if (mode == AuthFormMode.signUp) {
      if (displayName == null || displayName.trim().isEmpty) {
        throw const AppException('Enter your full name.');
      }
      final signUpRole = role ?? UserRole.vehicleOwner;
      final session = await _authRepository.registerWithPhone(
        phone: verifiedPhone,
        displayName: displayName.trim(),
        role: signUpRole,
      );
      await _sessionService.saveSession(session);
      state = AuthState.authenticated(session);
      return;
    }

    final session = await _authRepository.loginWithPhone(phone: verifiedPhone);
    await _sessionService.saveSession(session);
    state = AuthState.authenticated(session);
  }

  Future<void> signInWithGoogle() async {
    final profile = await sl<GoogleAuthService>().signInAndVerify(
      forceAccountPicker: true,
    );
    final session = await _authRepository.loginWithGoogle(
      email: profile.email,
      googleId: profile.googleId,
      displayName: profile.displayName,
    );
    await _sessionService.saveSession(session);
    state = AuthState.authenticated(session);
  }

  Future<void> signUpWithGoogle({
    required UserRole role,
  }) async {
    if (role == UserRole.admin || role == UserRole.employee) {
      throw const AppException('This role cannot be self-registered.');
    }

    final profile = await sl<GoogleAuthService>().signInAndVerify(
      forceAccountPicker: true,
    );

    // Existing Google/email users are signed in; new users are created with
    // the selected Vehicle Owner / Land Owner role only.
    final session = await _authRepository.registerWithGoogle(
      email: profile.email,
      googleId: profile.googleId,
      displayName: profile.displayName,
      role: role,
    );
    await _sessionService.saveSession(session);
    state = AuthState.authenticated(session);
  }

  Future<void> logout() async {
    try {
      await sl<GoogleAuthService>().signOut();
    } catch (_) {
      // App session must clear even if Google sign-out fails.
    }
    await _sessionService.clearSession();
    state = const AuthState.unauthenticated();
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(
    authRepository: sl<AuthRepository>(),
    sessionService: sl<SessionService>(),
  ),
);
