import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';

class PropertyDocumentVerificationResult {
  const PropertyDocumentVerificationResult({
    required this.accepted,
    required this.message,
    this.expectedType,
    this.detectedType,
  });

  final bool accepted;
  final String message;
  final String? expectedType;
  final String? detectedType;
}

class PropertyDocumentOcrService {
  PropertyDocumentOcrService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const _timeout = Duration(seconds: 180);

  Future<PropertyDocumentVerificationResult> verifyUpload({
    required String documentUrl,
    required String expectedType,
  }) async {
    try {
      final result = await _apiClient.post(
        '/api/ocr/property-document',
        {
          'documentUrl': documentUrl,
          'expectedType': expectedType,
        },
        timeout: _timeout,
      );

      return PropertyDocumentVerificationResult(
        accepted: result['accepted'] == true,
        message: (result['message'] as String?)?.trim().isNotEmpty == true
            ? result['message'] as String
            : 'Document verified.',
        expectedType: result['expectedType'] as String?,
        detectedType: result['detectedType'] as String?,
      );
    } on AppException {
      rethrow;
    }
  }
}
