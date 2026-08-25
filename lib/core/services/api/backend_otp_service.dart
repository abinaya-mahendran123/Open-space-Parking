import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';

class BackendOtpSendResult {
  const BackendOtpSendResult({
    required this.phone,
    required this.isDev,
    this.message,
  });

  /// Normalized E.164 phone number (e.g. +918148401544).
  final String phone;

  /// True when the backend has no SMS API key configured — OTP is in server logs.
  final bool isDev;
  final String? message;
}

class BackendOtpVerifyResult {
  const BackendOtpVerifyResult({
    required this.phone,
    required this.otpToken,
  });

  /// Verified phone number.
  final String phone;

  /// Short-lived HMAC token to pass to /api/auth/phone-login or phone-register.
  final String otpToken;
}

/// Sends and verifies phone OTPs through our own backend — no Firebase billing.
///
/// Uses Fast2SMS for SMS delivery (set FAST2SMS_API_KEY in backend/.env).
/// Without the key the OTP is printed to the backend console (dev mode).
class BackendOtpService {
  BackendOtpService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<BackendOtpSendResult> sendOtp(String phone) async {
    if (!PhoneUtils.isValidIndianMobile(phone)) {
      throw const AppException('Enter a valid 10-digit mobile number.');
    }
    final normalized = PhoneUtils.normalizeIndianMobile(phone);

    final response = await _apiClient
        .post(
          '/api/auth/otp/send',
          {'phone': normalized},
          authenticated: false,
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw const AppException(
            'OTP request timed out. Check your connection and try again.',
          ),
        );

    return BackendOtpSendResult(
      phone: response['phone'] as String? ?? normalized,
      isDev: response['dev'] as bool? ?? false,
      message: response['message'] as String?,
    );
  }

  Future<BackendOtpVerifyResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final normalized = PhoneUtils.normalizeIndianMobile(phone);

    final response = await _apiClient
        .post(
          '/api/auth/otp/verify',
          {
            'phone': normalized,
            'otp': otp.trim(),
          },
          authenticated: false,
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw const AppException(
            'OTP verification timed out. Try again.',
          ),
        );

    final token = response['token'] as String? ?? '';
    if (token.isEmpty) {
      throw const AppException('OTP verification failed. Please try again.');
    }

    return BackendOtpVerifyResult(
      phone: response['phone'] as String? ?? normalized,
      otpToken: token,
    );
  }
}
