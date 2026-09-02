import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
    this.detectedSide,
    this.ocrAccepted = false,
  });

  final String fullName;
  final String phone;
  final String address;
  final String governmentIdNumber;
  final String? aadhaarNumber;
  /// `back`, `front`, or null when unknown.
  final String? detectedSide;
  /// True when OCR extracted enough to accept this upload (name optional on back).
  final bool ocrAccepted;
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
    Uint8List? imageBytes,
  }) async {
    try {
      await _ensureApiAwake();
      return await _postExtract(
        frontUrl: frontUrl,
        backUrl: backUrl,
        idType: idType,
        imageBytes: imageBytes,
      );
    } on AppException catch (error) {
      if (_looksGatewayTimeout(error.message)) {
        await Future<void>.delayed(const Duration(seconds: 3));
        await _ensureApiAwake();
        return _postExtract(
          frontUrl: frontUrl,
          backUrl: backUrl,
          idType: idType,
          imageBytes: imageBytes,
        );
      }
      if (!_looksUnreachable(error.message)) rethrow;
      await EnvironmentConfig.refreshReachableApiUrl();
      await _ensureApiAwake();
      return _postExtract(
        frontUrl: frontUrl,
        backUrl: backUrl,
        idType: idType,
        imageBytes: imageBytes,
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

  /// Fast health check first; long backoff only when the API is unreachable (e.g. sleeping Render).
  Future<void> _ensureApiAwake() async {
    try {
      await _apiClient.checkHealth().timeout(const Duration(seconds: 5));
      return;
    } catch (_) {
      // Fall through to backoff only when the first ping fails.
    }

    NetworkException? lastError;
    for (var i = 0; i < _wakeAttempts; i += 1) {
      try {
        await _apiClient.checkHealth().timeout(const Duration(seconds: 8));
        return;
      } on NetworkException catch (error) {
        lastError = error;
        if (i < _wakeAttempts - 1) {
          await Future<void>.delayed(_wakeDelay);
          await EnvironmentConfig.refreshReachableApiUrl();
        }
      } on TimeoutException {
        if (i < _wakeAttempts - 1) {
          await Future<void>.delayed(_wakeDelay);
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
    Uint8List? imageBytes,
  }) async {
    final body = <String, dynamic>{
      'frontUrl': frontUrl,
      'backUrl': backUrl,
      'idType': idType.apiValue,
    };

    // Prefer inline bytes so OCR still works after Render redeploys wipe /uploads.
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final b64 = base64Encode(imageBytes);
      body['frontBase64'] = b64;
      body['backBase64'] = b64;
    }

    final response = await _apiClient.post(
      '/api/ocr/government-id',
      body,
      timeout: _ocrTimeout,
    );

    return GovernmentIdExtractionResult(
      fullName: (response['fullName'] as String? ?? '').trim(),
      phone: (response['phone'] as String? ?? '').trim(),
      address: (response['address'] as String? ?? '').trim(),
      governmentIdNumber:
          (response['governmentIdNumber'] as String? ?? '').trim(),
      aadhaarNumber: (response['aadhaarNumber'] as String?)?.trim(),
      detectedSide: (response['detectedSide'] as String?)?.trim(),
      ocrAccepted: response['ocrAccepted'] == true,
    );
  }

  bool _looksUnreachable(String message) {
    final text = message.toLowerCase();
    return text.contains('cannot reach') ||
        text.contains('internet') ||
        text.contains('wake');
  }

  bool _looksGatewayTimeout(String message) {
    final text = message.toLowerCase();
    return text.contains('http 502') ||
        text.contains('http 504') ||
        text.contains('bad gateway') ||
        text.contains('gateway timeout');
  }
}
