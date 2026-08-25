import 'dart:async';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
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

  Future<GovernmentIdExtractionResult> extractDetails({
    required String frontUrl,
    required String backUrl,
    required GovernmentIdType idType,
  }) async {
    try {
      return await _postExtract(
        frontUrl: frontUrl,
        backUrl: backUrl,
        idType: idType,
      );
    } on AppException catch (error) {
      if (!_looksUnreachable(error.message)) rethrow;
      await EnvironmentConfig.refreshReachableApiUrl();
      try {
        await _apiClient.checkHealth();
      } catch (_) {}
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
      throw AppException('Could not read Aadhaar card: ${e.toString()}');
    }
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
