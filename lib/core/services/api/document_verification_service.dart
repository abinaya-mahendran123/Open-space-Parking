import 'dart:async';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/features/admin/domain/entities/document_verification_report.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';

class DocumentVerificationService {
  DocumentVerificationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Multi-document OCR routinely exceeds the default 30s API timeout.
  static const _timeout = Duration(minutes: 5);

  Future<DocumentVerificationReport> verifyTicket({
    required OwnerDetails ownerDetails,
    required LandOwnerDocuments documents,
    required LandDetails landDetails,
  }) async {
    try {
      final result = await _apiClient.post(
        '/api/admin/document-verification',
        {
          'ownerDetails': ownerDetails.toJson(),
          'documents': documents.toJson(),
          'landDetails': landDetails.toJson(),
        },
        timeout: _timeout,
      );

      return DocumentVerificationReport.fromJson(result);
    } on TimeoutException {
      throw const AppException(
        'Document cross-check timed out. OCR can take a few minutes — tap Retry.',
      );
    } on AppException {
      rethrow;
    }
  }
}
