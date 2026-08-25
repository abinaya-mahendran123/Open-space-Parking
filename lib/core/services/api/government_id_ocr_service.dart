import 'dart:async';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/government_id_type.dart';

class GovernmentIdExtractionResult {
  const GovernmentIdExtractionResult({
    required this.fullName,
    required this.phone,
    required this.address,
    required this.governmentIdNumber,
    this.aadhaarNumber,
  });

  final String fullName;
  final String phone;
  final String address;
  final String governmentIdNumber;
  final String? aadhaarNumber;
}

class GovernmentIdOcrService {
  GovernmentIdOcrService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// OCR is multi-pass; cold Paddle model download can exceed 2 minutes.
  static const _ocrTimeout = Duration(seconds: 180);

  /// Render free tier often sleeps; wake before uploading OCR work.
  static const _wakeAttempts = 8;
  static const _wakeDelay = Duration(seconds: 8);

  Future<GovernmentIdExtractionResult> extractDetails({
    required String frontUrl,
    required String backUrl,
    required GovernmentIdType idType,
  }) async {
    try {
      await _ensureApiAwake();
      return await _postExtract(
        frontUrl: frontUrl,
        backUrl: backUrl,
        idType: idType,
      );
    } on AppException catch (error) {
      if (!_looksUnreachable(error.message)) rethrow;
      await EnvironmentConfig.refreshReachableApiUrl();
      await _ensureApiAwake();
      return _postExtract(
        frontUrl: frontUrl,
        backUrl: backUrl,
        idType: idType,
      );
    } on TimeoutException {
      throw const AppException(
        'Aadhaar scan is taking too long. Please try again — it usually completes faster on the second attempt.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Could not read Aadhaar card: ${e.toString()}');
    }
  }

  /// Ping /api/health with backoff so a waking Render instance can finish boot.
  Future<void> _ensureApiAwake() async {
    NetworkException? lastError;
    for (var i = 0; i < _wakeAttempts; i += 1) {
      try {
        await _apiClient.checkHealth();
        return;
      } on NetworkException catch (error) {
        lastError = error;
        if (i < _wakeAttempts - 1) {
          await Future<void>.delayed(_wakeDelay);
          await EnvironmentConfig.refreshReachableApiUrl();
        }
      }
    }
    throw lastError ??
        const NetworkException(EnvironmentConfig.phoneUnreachableMessage);
  }

  Future<GovernmentIdExtractionResult> _postExtract({
    required String frontUrl,
    required String backUrl,
    required GovernmentIdType idType,
  }) async {
    final response = await _apiClient.post(
      '/api/ocr/government-id',
      {
        'frontUrl': frontUrl,
        'backUrl': backUrl,
        'idType': idType.apiValue,
      },
      timeout: _ocrTimeout,
    );

    return GovernmentIdExtractionResult(
      fullName: (response['fullName'] as String? ?? '').trim(),
      phone: (response['phone'] as String? ?? '').trim(),
      address: (response['address'] as String? ?? '').trim(),
      governmentIdNumber:
          (response['governmentIdNumber'] as String? ?? '').trim(),
      aadhaarNumber: (response['aadhaarNumber'] as String?)?.trim(),
    );
  }

  bool _looksUnreachable(String message) {
    final text = message.toLowerCase();
    return text.contains('cannot reach') ||
        text.contains('internet') ||
        text.contains('wake');
  }
}
