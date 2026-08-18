import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_asset.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';

typedef UploadProgressCallback = void Function(double progress);

abstract class CloudinaryRepository {
  Future<CloudinaryAsset> uploadFile({
    required List<int> fileBytes,
    required String fileName,
    required CloudinaryFileCategory category,
    required String ownerId,
    required String ownerType,
    String? referenceId,
    UploadProgressCallback? onProgress,
  });

  Future<void> deleteAsset(CloudinaryAsset asset);

  Future<void> deleteByUrl(String url, {String? publicId, String? resourceType});

  Future<List<CloudinaryAsset>> getAssetsForOwner(String ownerId);
}
