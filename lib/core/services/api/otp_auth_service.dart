import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';

class OtpSendResult {
  const OtpSendResult({
    required this.phone,
    required this.devMode,
  });

  final String phone;
  final bool devMode;
}

class OtpAuthService {
  OtpAuthService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<OtpSendResult> sendOtp(String phone) async {
    final normalizedPhone = PhoneUtils.normalizeIndianMobile(phone);
    if (!PhoneUtils.isValidIndianMobile(phone)) {
      throw const AppException('Enter a valid 10-digit mobile number.');
    }

    final response = await _post(
      '/api/auth/send-otp',
      {'phone': normalizedPhone},
    );

    return OtpSendResult(
      phone: response['phone']?.toString() ?? normalizedPhone,
      devMode: response['devMode'] == true,
    );
  }

  Future<String> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final normalizedPhone = PhoneUtils.normalizeIndianMobile(phone);
    final response = await _post(
      '/api/auth/verify-otp',
      {
        'phone': normalizedPhone,
        'otp': otp.trim(),
      },
    );

    if (response['verified'] != true) {
      throw const AppException('OTP verification failed.');
    }

    return response['phone']?.toString() ?? normalizedPhone;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${EnvironmentConfig.baseApiUrl}$path');
    http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } on http.ClientException {
      try {
        final retriedUrl = await EnvironmentConfig.refreshReachableApiUrl();
        response = await _httpClient.post(
          Uri.parse('$retriedUrl$path'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } catch (_) {
        throw AppException(
          'Could not reach the auth server at ${EnvironmentConfig.baseApiUrl}. '
          'On a phone, localhost is the phone — not your PC. Keep USB plugged in, '
          'run adb reverse tcp:3000 tcp:3000, keep backend running (npm start), '
          'and use the same Wi-Fi as the PC.',
        );
      }
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AppException('Invalid response from auth server.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        payload['error']?.toString() ?? 'Authentication request failed.',
      );
    }

    if (payload['ok'] != true) {
      throw const AppException('Authentication request was not accepted.');
    }

    return payload;
  }
}
