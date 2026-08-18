import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';

class GoogleAuthProfile {
  const GoogleAuthProfile({
    required this.email,
    required this.googleId,
    required this.displayName,
    required this.emailVerified,
  });

  final String email;
  final String googleId;
  final String displayName;
  final bool emailVerified;
}

/// Official Google Sign-In via `google_sign_in` for Android, iOS, and Web.
///
/// Does not collect Google passwords. Uses Google's account picker /
/// Identity Services UI. Client secrets never ship in the Flutter app.
class GoogleAuthService {
  GoogleAuthService({
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
  })  : _googleSignIn = googleSignIn ?? _createGoogleSignIn(),
        _httpClient = httpClient ?? http.Client();

  final GoogleSignIn _googleSignIn;
  final http.Client _httpClient;

  static GoogleSignIn _createGoogleSignIn() {
    final webClientId = EnvironmentConfig.googleWebClientId.trim();
    final serverClientId = EnvironmentConfig.googleServerClientId.trim();

    return GoogleSignIn(
      // Web OAuth client ID (also used by google_sign_in_web).
      clientId: webClientId.isEmpty ? null : webClientId,
      // Required on Android/iOS so Google returns a usable ID token.
      serverClientId: serverClientId.isEmpty
          ? (webClientId.isEmpty ? null : webClientId)
          : serverClientId,
      scopes: const <String>['email', 'profile', 'openid'],
    );
  }

  bool get isConfigured => EnvironmentConfig.googleWebClientId.trim().isNotEmpty;

  /// Opens Google's official account picker / auth UI, then verifies identity.
  ///
  /// [forceAccountPicker] signs out of any cached Google session first so the
  /// user can switch accounts or add another account.
  Future<GoogleAuthProfile> signInAndVerify({
    bool forceAccountPicker = true,
  }) async {
    if (!isConfigured) {
      throw const AppException(
        'Google sign-in is not configured for this build.',
      );
    }

    try {
      if (forceAccountPicker) {
        await _clearCachedGoogleSession();
      }

      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AppException('Google sign-in was cancelled.');
      }

      final auth = await account.authentication;
      final idToken = auth.idToken?.trim() ?? '';

      if (idToken.isNotEmpty) {
        return verifyIdToken(idToken);
      }

      // Rare web edge case: account selected but ID token not yet issued.
      if (kIsWeb && account.email.trim().isNotEmpty && account.id.trim().isNotEmpty) {
        AppLogger.w(
          'Google ID token missing on web; verifying via account identity.',
        );
        return GoogleAuthProfile(
          email: account.email.trim().toLowerCase(),
          googleId: account.id.trim(),
          displayName:
              (account.displayName ?? account.email.split('@').first).trim(),
          emailVerified: true,
        );
      }

      throw const AppException(
        'Could not complete Google sign-in. Please try again.',
      );
    } on AppException {
      rethrow;
    } catch (e, st) {
      AppLogger.e('Google sign-in failed', e, st);
      throw AppException(_mapGoogleError(e));
    }
  }

  Future<GoogleAuthProfile> verifyIdToken(String idToken) async {
    Future<http.Response> send() {
      return _httpClient
          .post(
            Uri.parse('${EnvironmentConfig.baseApiUrl}/api/auth/google'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idToken': idToken,
              'clientId': EnvironmentConfig.googleWebClientId,
            }),
          )
          .timeout(const Duration(seconds: 20));
    }

    http.Response response;
    try {
      response = await send();
    } catch (_) {
      await EnvironmentConfig.refreshReachableApiUrl();
      try {
        response = await send();
      } catch (_) {
        throw const AppException(EnvironmentConfig.phoneUnreachableMessage);
      }
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AppException('Invalid response from Google auth server.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        body['error']?.toString() ?? 'Google sign-in verification failed.',
      );
    }

    if (body['ok'] != true) {
      throw const AppException('Google sign-in was not accepted.');
    }

    final email = body['email']?.toString().trim().toLowerCase() ?? '';
    final googleId = body['googleId']?.toString().trim() ?? '';
    if (email.isEmpty || googleId.isEmpty) {
      throw const AppException('Google account identity is incomplete.');
    }

    return GoogleAuthProfile(
      email: email,
      googleId: googleId,
      displayName: body['displayName']?.toString().trim().isNotEmpty == true
          ? body['displayName'].toString().trim()
          : email.split('@').first,
      emailVerified: body['emailVerified'] == true,
    );
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      AppLogger.w('Google signOut failed: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      AppLogger.w('Google disconnect failed: $e');
      await signOut();
    }
  }

  Future<void> _clearCachedGoogleSession() async {
    try {
      final current = _googleSignIn.currentUser;
      if (current != null) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      AppLogger.w('Clearing Google session failed: $e');
    }
  }

  String _mapGoogleError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('failed host lookup')) {
      return 'Network error during Google sign-in. Check your connection.';
    }
    if (message.contains('popup_closed_by_user') ||
        message.contains('canceled') ||
        message.contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    }
    if (message.contains('idpiframe_initialization_failed') ||
        message.contains('clientid') ||
        message.contains('client_id') ||
        message.contains('10:') ||
        message.contains('developer_error') ||
        message.contains('api_not_available')) {
      return 'Google sign-in configuration error. '
          'Check OAuth client IDs and authorized origins.';
    }
    if (message.contains('sign_in_failed') || message.contains('12500')) {
      return 'Google sign-in failed. Please try again.';
    }
    return 'Google sign-in failed. Please try again.';
  }
}
