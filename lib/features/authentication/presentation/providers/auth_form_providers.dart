import 'package:flutter_riverpod/flutter_riverpod.dart';

final authLoadingProvider = StateProvider<bool>((ref) => false);

enum AuthFormMode { signIn, signUp }

enum AuthMethod { phone, emailGoogle }

enum PhoneAuthStep {
  enterPhone,
  enterEmployeePassword,
  enterSecurityPassword,
  enterOtp,
}

final authFormModeProvider = StateProvider<AuthFormMode>(
  (ref) => AuthFormMode.signIn,
);

final authMethodProvider = StateProvider<AuthMethod>(
  (ref) => AuthMethod.phone,
);

final phoneAuthStepProvider = StateProvider<PhoneAuthStep>(
  (ref) => PhoneAuthStep.enterPhone,
);

class PendingRegistration {
  const PendingRegistration({
    required this.email,
    required this.password,
    required this.displayName,
  });

  final String email;
  final String password;
  final String displayName;
}

final pendingRegistrationProvider =
    StateProvider<PendingRegistration?>((ref) => null);

/// Set after sign-in when user must confirm role before entering the app.
final postAuthRoleSelectionProvider = StateProvider<bool>((ref) => false);

final verifiedPhoneProvider = StateProvider<String?>((ref) => null);
