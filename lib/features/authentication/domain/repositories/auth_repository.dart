import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

abstract class AuthRepository {
  Future<AuthSession> loginAppUser({
    required String email,
    required String password,
  });

  Future<AuthSession> loginAdmin({
    required String email,
    required String password,
  });

  Future<AuthSession> loginEmployee({
    required String phone,
    required String password,
  });

  Future<AuthSession> loginSecurity({
    required String email,
    required String password,
  });

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  });

  Future<void> requestPasswordReset({required String email});

  Future<AuthSession> loginWithPhone({
    required String phone,
    String? idToken,
    String? otpToken,
  });

  Future<AuthSession> registerWithPhone({
    required String phone,
    required String displayName,
    required UserRole role,
    String? idToken,
    String? otpToken,
  });

  Future<AuthSession> loginWithGoogle({
    required String email,
    required String googleId,
    required String displayName,
  });

  Future<AuthSession> registerWithGoogle({
    required String email,
    required String googleId,
    required String displayName,
    required UserRole role,
  });
}
