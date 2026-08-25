import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/bootstrap/app_bootstrap.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/services/api/google_auth_service.dart';
import 'package:open_space_parking/core/services/api/account_check_service.dart';
import 'package:open_space_parking/core/services/api/backend_otp_service.dart';
import 'package:open_space_parking/core/services/api/otp_auth_service.dart';
import 'package:open_space_parking/core/services/session_service.dart';
import 'package:open_space_parking/core/services/auth_token_provider.dart';
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
    required AuthTokenProvider authTokenProvider,
  })  : _authRepository = authRepository,
        _sessionService = sessionService,
        _authTokenProvider = authTokenProvider,
        super(const AuthState.unknown()) {
    initialize();
  }

  final AuthRepository _authRepository;
  final SessionService _sessionService;
  final AuthTokenProvider _authTokenProvider;

  Future<void> initialize() async {
    try {
      final session = await _sessionService.readSession();
      if (session == null || session.isExpired) {
        await _sessionService.clearSession();
        _authTokenProvider.clear();
        state = const AuthState.unauthenticated();
        return;
      }
      _authTokenProvider.setToken(session.jwtToken);
      state = AuthState.authenticated(session);
    } catch (_) {
      _authTokenProvider.clear();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    await _sessionService.saveSession(session);
    _authTokenProvider.setToken(session.jwtToken);
    state = AuthState.authenticated(session);
  }

  void setSelectedRole(UserRole role) {
    state = state.copyWith(selectedRole: role);
  }

  Future<void> _ensureApiReady() async {
    await EnvironmentConfig.refreshReachableApiUrl();
    if (!AppBootstrap.mongoReady) {
      await AppBootstrap.retryApi();
    }
  }

  Future<void> loginAppUser({
    required String email,
    required String password,
  }) async {
    await _ensureApiReady();
    AppException? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final session = await _authRepository.loginAppUser(
          email: email,
          password: password,
        );
        await _persistSession(session);
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
    await _ensureApiReady();
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
    return message.contains('cannot reach the server') ||
        message.contains('unavailable') ||
        message.contains('timed out') ||
        message.contains('network');
  }

  Future<void> loginAdmin({
    required String email,
    required String password,
  }) async {
    await _ensureApiReady();
    final session = await _authRepository.loginAdmin(
      email: email,
      password: password,
    );
    await _persistSession(session);
  }

  Future<void> loginEmployee({
    required String phone,
    required String password,
  }) async {
    await _ensureApiReady();
    final session = await _authRepository.loginEmployee(
      phone: phone,
      password: password,
    );
    await _persistSession(session);
  }

  Future<void> loginSecurity({
    required String phone,
    required String password,
  }) async {
    await _ensureApiReady();
    final session = await _authRepository.loginSecurity(
      phone: phone,
      password: password,
    );
    await _persistSession(session);
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
    await _persistSession(session);
  }

  Future<void> forgotPassword(String email) {
    return _authRepository.requestPasswordReset(email: email);
  }

  Future<PhoneAccountType> checkPhoneAccount(String phone) async {
    await _ensureApiReady();
    return sl<AccountCheckService>().checkAccount(phone);
  }

  Future<OtpSendResult> sendPhoneOtp(String phone) async {
    await _ensureApiReady();
    try {
      final result = await BackendOtpService().sendOtp(phone);
      return OtpSendResult(
        phone: result.phone,
        autoVerified: false,
        devMode: result.isDev,
        message: result.message,
      );
    } on AppException catch (e) {
      throw AppException('${e.message} [API ${EnvironmentConfig.baseApiUrl}]');
    } catch (e) {
      throw AppException(
        'OTP send failed: $e [API ${EnvironmentConfig.baseApiUrl}]',
      );
    }
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String otp,
    required AuthFormMode mode,
    String? displayName,
    UserRole? role,
  }) async {
    await _ensureApiReady();

    final verified = await BackendOtpService().verifyOtp(phone: phone, otp: otp);
    final otpToken = verified.otpToken;
    phone = verified.phone;
    const String? idToken = null;

    if (mode == AuthFormMode.signUp) {
      if (displayName == null || displayName.trim().isEmpty) {
        throw const AppException('Enter your full name.');
      }
      final signUpRole = role ?? UserRole.vehicleOwner;
      final session = await _authRepository.registerWithPhone(
        phone: phone,
        displayName: displayName.trim(),
        role: signUpRole,
        idToken: idToken,
        otpToken: otpToken,
      );
      await _persistSession(session);
      return;
    }

    await _persistSession(
      await _authRepository.loginWithPhone(
      phone: phone,
      idToken: idToken,
      otpToken: otpToken,
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    await _ensureApiReady();
    final profile = await sl<GoogleAuthService>().signInAndVerify(
      forceAccountPicker: true,
    );
    await _persistSession(
      await _authRepository.loginWithGoogle(
        email: profile.email,
        googleId: profile.googleId,
        displayName: profile.displayName,
      ),
    );
  }

  Future<void> signUpWithGoogle({
    required UserRole role,
  }) async {
    if (role == UserRole.admin ||
        role == UserRole.employee ||
        role == UserRole.security) {
      throw const AppException('This role cannot be self-registered.');
    }

    await _ensureApiReady();
    final profile = await sl<GoogleAuthService>().signInAndVerify(
      forceAccountPicker: true,
    );

    // Existing Google/email users are signed in; new users are created with
    // the selected Vehicle Owner / Land Owner role only.
    await _persistSession(
      await _authRepository.registerWithGoogle(
        email: profile.email,
        googleId: profile.googleId,
        displayName: profile.displayName,
        role: role,
      ),
    );
  }

  Future<void> logout() async {
    // Clear auth state first so GoRouter cannot bounce users back while
    // session storage and identity providers are still clearing.
    state = const AuthState.unauthenticated();
    _authTokenProvider.clear();
    try {
      await _sessionService.clearSession().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await sl<GoogleAuthService>().signOut().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await sl<OtpAuthService>().signOut().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(
    authRepository: sl<AuthRepository>(),
    sessionService: sl<SessionService>(),
    authTokenProvider: sl<AuthTokenProvider>(),
  ),
);
