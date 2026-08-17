import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:open_space_parking/core/cloudinary/data/services/cloudinary_validation_service.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_asset.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/upload_progress.dart';
import 'package:open_space_parking/core/cloudinary/domain/repositories/cloudinary_repository.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';

final cloudinaryRepositoryProvider = Provider<CloudinaryRepository>(
  (ref) => GetIt.I<CloudinaryRepository>(),
);

final cloudinaryValidationServiceProvider = Provider<CloudinaryValidationService>(
  (ref) => GetIt.I<CloudinaryValidationService>(),
);

class CloudinaryUploadController extends StateNotifier<UploadProgress> {
  CloudinaryUploadController(this._repository) : super(const UploadProgress());

  final CloudinaryRepository _repository;

  Future<CloudinaryAsset?> upload({
    required List<int> fileBytes,
    required String fileName,
    required CloudinaryFileCategory category,
    required String ownerId,
    required String ownerType,
    String? referenceId,
  }) async {
    state = state.copyWith(
      status: UploadStatus.validating,
      progress: 0,
      clearError: true,
    );

    try {
      state = state.copyWith(status: UploadStatus.uploading);

      final asset = await _repository.uploadFile(
        fileBytes: fileBytes,
        fileName: fileName,
        category: category,
        ownerId: ownerId,
        ownerType: ownerType,
        referenceId: referenceId,
        onProgress: (value) {
          state = state.copyWith(progress: value);
        },
      );

      state = state.copyWith(
        status: UploadStatus.completed,
        progress: 1,
      );
      return asset;
    } on AppException catch (e) {
      state = state.copyWith(
        status: UploadStatus.failed,
        errorMessage: e.message,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        status: UploadStatus.failed,
        errorMessage: 'Upload failed. Please try again.',
      );
      return null;
    }
  }

  Future<bool> delete(CloudinaryAsset asset) async {
    try {
      await _repository.deleteAsset(asset);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: UploadStatus.failed,
        errorMessage: e.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: UploadStatus.failed,
        errorMessage: 'Delete failed. Please try again.',
      );
      return false;
    }
  }

  void reset() {
    state = const UploadProgress();
  }
}

final cloudinaryUploadControllerProvider =
    StateNotifierProvider.autoDispose<CloudinaryUploadController, UploadProgress>(
  (ref) => CloudinaryUploadController(ref.watch(cloudinaryRepositoryProvider)),
);

final ownerCloudinaryAssetsProvider =
    FutureProvider.family<List<CloudinaryAsset>, String>(
  (ref, ownerId) async {
    if (ownerId.isEmpty) return [];
    return ref.watch(cloudinaryRepositoryProvider).getAssetsForOwner(ownerId);
  },
);
