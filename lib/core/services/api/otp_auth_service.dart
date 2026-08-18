import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';

class OtpSendResult {
  const OtpSendResult({
    required this.phone,
    required this.devMode,
    this.otp,
  });

  final String phone;
  final bool devMode;
  final String? otp;
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
      otp: response['otp']?.toString(),
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
    Future<http.Response> postTo(String base) {
      return _httpClient
          .post(
            Uri.parse('$base$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppConstants.requestTimeout);
    }

    http.Response response;
    try {
      response = await postTo(EnvironmentConfig.baseApiUrl);
    } catch (error) {
      final text = error.toString().toLowerCase();
      final isTransport = error is TimeoutException ||
          error is http.ClientException ||
          text.contains('socket') ||
          text.contains('connection') ||
          text.contains('timed out');
      if (!isTransport) rethrow;
      response = await _retryPost(postTo);
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

  Future<http.Response> _retryPost(
    Future<http.Response> Function(String base) postTo,
  ) async {
    try {
      final retriedUrl = await EnvironmentConfig.refreshReachableApiUrl();
      return await postTo(retriedUrl);
    } catch (_) {
      throw const AppException(EnvironmentConfig.phoneUnreachableMessage);
    }
  }
}
