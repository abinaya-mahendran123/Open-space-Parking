import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/firebase/firebase_bootstrap.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';

class OtpSendResult {
  const OtpSendResult({
    required this.phone,
    this.autoVerified = false,
    this.devMode = false,
    this.message,
  });

  final String phone;
  final bool autoVerified;
  final bool devMode;
  final String? message;
}

class OtpVerifyResult {
  const OtpVerifyResult({
    required this.phone,
    required this.idToken,
  });

  final String phone;
  final String idToken;
}

/// Sends and verifies phone OTPs through Firebase Authentication.
class OtpAuthService {
  OtpAuthService({FirebaseAuth? firebaseAuth}) : _authOverride = firebaseAuth;

  final FirebaseAuth? _authOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;
  String? _pendingPhone;
  String? _autoIdToken;

  Future<void> _ensureFirebase() async {
    if (!EnvironmentConfig.isFirebaseAuthConfigured) {
      throw const AppException(
        'Firebase Phone Auth is not configured. Enable Phone sign-in in the '
        'Firebase console and pass FIREBASE_API_KEY, FIREBASE_APP_ID, '
        'FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID '
        '(plus FIREBASE_AUTH_DOMAIN on web).',
      );
    }
    await FirebaseBootstrap.ensureInitialized();
    if (!FirebaseBootstrap.ready) {
      throw const AppException(
        'Could not start Firebase. Run flutterfire configure or pass Firebase '
        'dart-defines, then restart the app.',
      );
    }
    if (kDebugMode) {
      await _auth.setSettings(appVerificationDisabledForTesting: true);
    }
  }

  Future<OtpSendResult> sendOtp(String phone) async {
    await _ensureFirebase();
    if (!PhoneUtils.isValidIndianMobile(phone)) {
      throw const AppException('Enter a valid 10-digit mobile number.');
    }

    final e164 = PhoneUtils.normalizeIndianMobile(phone);
    _pendingPhone = e164;
    _autoIdToken = null;
    _webConfirmation = null;
    _verificationId = null;

    if (kIsWeb) {
      try {
        _webConfirmation = await _auth.signInWithPhoneNumber(e164);
        return OtpSendResult(phone: e164);
      } on FirebaseAuthException catch (error) {
        AppLogger.w(
          'Firebase phone auth failed [${error.code}]: ${error.message}',
        );
        throw AppException(_mapFirebaseError(error));
      }
    }

    final completer = Completer<OtpSendResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: e164,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final userCred = await _auth.signInWithCredential(credential);
          _autoIdToken = await userCred.user?.getIdToken();
          final result = OtpSendResult(phone: e164, autoVerified: true);
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        } catch (_) {
          if (!completer.isCompleted) {
            completer.completeError(
              const AppException(
                'Automatic verification failed. Enter the SMS code.',
              ),
            );
          }
        }
      },
      verificationFailed: (FirebaseAuthException error) {
        if (!completer.isCompleted) {
          completer.completeError(AppException(_mapFirebaseError(error)));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) {
          completer.complete(OtpSendResult(phone: e164));
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        throw const AppException(
          'Timed out waiting for Firebase to send the SMS. Try again.',
        );
      },
    );
  }

  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    await _ensureFirebase();
    final e164 = PhoneUtils.normalizeIndianMobile(phone);

    try {
      if (_autoIdToken != null && _autoIdToken!.isNotEmpty) {
        return OtpVerifyResult(phone: e164, idToken: _autoIdToken!);
      }

      if (kIsWeb) {
        final confirmation = _webConfirmation;
        if (confirmation == null) {
          throw const AppException('Request a new OTP, then try again.');
        }
        final credential = await confirmation.confirm(otp.trim());
        return await _tokenFromUser(credential.user, e164);
      }

      final verificationId = _verificationId;
      if (verificationId == null || verificationId.isEmpty) {
        throw const AppException('Request a new OTP, then try again.');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp.trim(),
      );
      final userCred = await _auth.signInWithCredential(credential);
      return await _tokenFromUser(userCred.user, e164);
    } on FirebaseAuthException catch (error) {
      throw AppException(_mapFirebaseError(error));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _verificationId = null;
    _resendToken = null;
    _webConfirmation = null;
    _pendingPhone = null;
    _autoIdToken = null;
  }

  Future<OtpVerifyResult> _tokenFromUser(User? user, String fallbackPhone) async {
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AppException('Firebase did not return a sign-in token.');
    }
    final phone = user?.phoneNumber ?? _pendingPhone ?? fallbackPhone;
    return OtpVerifyResult(phone: phone, idToken: token);
  }

  String _mapFirebaseError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-phone-number' => 'Enter a valid mobile number with country code.',
      'too-many-requests' => 'Too many OTP attempts. Wait a few minutes and try again.',
      'quota-exceeded' => 'SMS quota exceeded. Try again later.',
      'session-expired' => 'This OTP expired. Request a new code.',
      'invalid-verification-code' => 'Invalid OTP. Check the SMS and try again.',
      'invalid-verification-id' => 'Request a new OTP, then try again.',
      'missing-client-identifier' =>
        'Android SHA-1 is missing in Firebase. Add your debug SHA-1 and retry.',
      'app-not-authorized' =>
        'This app is not authorized for Firebase Phone Auth yet.',
      'operation-not-allowed' =>
        'Allow India for SMS in Firebase: Authentication → Settings → '
        'SMS region policy → allow India (IN), then Save and retry.',
      'captcha-check-failed' => 'reCAPTCHA failed. Refresh and try again.',
      'network-request-failed' => 'Network error. Check your connection.',
      _ => error.message?.trim().isNotEmpty == true
          ? '${error.message} (${error.code})'
          : 'Could not complete phone verification (${error.code}).',
    };
  }
}
