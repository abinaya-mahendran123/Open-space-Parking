import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/government_id_ocr_service.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/government_id_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';

/// Background Aadhaar OCR job — survives step navigation in parking flows.
class AadhaarOcrState {
  const AadhaarOcrState({
    this.isRunning = false,
    this.uploadUrl,
    this.imageBytes,
    this.result,
    this.error,
    this.jobId = 0,
  });

  final bool isRunning;
  final String? uploadUrl;
  final Uint8List? imageBytes;
  final GovernmentIdExtractionResult? result;
  final String? error;
  final int jobId;

  AadhaarOcrState copyWith({
    bool? isRunning,
    String? uploadUrl,
    Uint8List? imageBytes,
    GovernmentIdExtractionResult? result,
    String? error,
    int? jobId,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return AadhaarOcrState(
      isRunning: isRunning ?? this.isRunning,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      imageBytes: imageBytes ?? this.imageBytes,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      jobId: jobId ?? this.jobId,
    );
  }
}

class AadhaarOcrNotifier extends StateNotifier<AadhaarOcrState> {
  AadhaarOcrNotifier({GovernmentIdOcrService? ocrService})
      : _ocrService = ocrService ?? GovernmentIdOcrService(),
        super(const AadhaarOcrState());

  final GovernmentIdOcrService _ocrService;
  int _nextJobId = 0;

  /// Starts OCR without blocking the UI. Duplicate in-flight jobs for the same URL are ignored.
  void startExtract({
    required String uploadUrl,
    Uint8List? imageBytes,
    GovernmentIdType idType = GovernmentIdType.aadhaar,
  }) {
    if (uploadUrl.isEmpty) return;
    if (state.isRunning && state.uploadUrl == uploadUrl) return;

    final jobId = ++_nextJobId;
    state = AadhaarOcrState(
      isRunning: true,
      uploadUrl: uploadUrl,
      imageBytes: imageBytes,
      jobId: jobId,
    );

    _runJob(jobId, uploadUrl, imageBytes, idType);
  }

  Future<void> _runJob(
    int jobId,
    String uploadUrl,
    Uint8List? imageBytes,
    GovernmentIdType idType,
  ) async {
    try {
      final result = await _ocrService.extractDetails(
        frontUrl: uploadUrl,
        backUrl: uploadUrl,
        idType: idType,
        imageBytes: imageBytes,
      );
      if (!mounted || state.jobId != jobId) return;
      state = AadhaarOcrState(
        isRunning: false,
        uploadUrl: uploadUrl,
        imageBytes: imageBytes,
        result: result,
        jobId: jobId,
      );
    } on AppException catch (error) {
      if (!mounted || state.jobId != jobId) return;
      state = AadhaarOcrState(
        isRunning: false,
        uploadUrl: uploadUrl,
        imageBytes: imageBytes,
        error: error.message,
        jobId: jobId,
      );
    } catch (_) {
      if (!mounted || state.jobId != jobId) return;
      state = AadhaarOcrState(
        isRunning: false,
        uploadUrl: uploadUrl,
        imageBytes: imageBytes,
        error: 'Could not read Aadhaar card. Please fill in manually.',
        jobId: jobId,
      );
    }
  }

  void reset() {
    state = const AadhaarOcrState();
  }
}

final aadhaarOcrProvider =
    StateNotifierProvider<AadhaarOcrNotifier, AadhaarOcrState>(
  (ref) => AadhaarOcrNotifier(),
);

/// Merge OCR output into [OwnerDetails] for form / flow state.
OwnerDetails ownerDetailsFromOcr({
  required GovernmentIdExtractionResult result,
  required String uploadedUrl,
  String? accountEmail,
  OwnerDetails? existing,
}) {
  final idNumber = (result.aadhaarNumber?.isNotEmpty == true
          ? result.aadhaarNumber!
          : result.governmentIdNumber)
      .replaceAll(RegExp(r'\D'), '');

  final email = ProfilePrefill.firstNonEmpty([
    ProfilePrefill.realEmail(accountEmail),
    accountEmail,
    existing?.email,
  ]);

  return OwnerDetails(
    fullName: result.fullName.isNotEmpty
        ? result.fullName
        : (existing?.fullName ?? ''),
    phone: result.phone.isNotEmpty &&
            RegExp(r'^[6-9]\d{9}$').hasMatch(result.phone)
        ? result.phone
        : (existing?.phone ?? ''),
    email: email,
    address: result.address.isNotEmpty
        ? result.address
        : (existing?.address ?? ''),
    aadhaarNumber:
        idNumber.length == 12 ? idNumber : (existing?.aadhaarNumber ?? ''),
    governmentIdType: GovernmentIdType.aadhaar,
    governmentIdNumber:
        idNumber.length == 12 ? idNumber : (existing?.governmentIdNumber ?? ''),
    governmentIdFrontPath: uploadedUrl,
    governmentIdBackPath: uploadedUrl,
  );
}
