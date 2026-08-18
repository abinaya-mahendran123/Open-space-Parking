import 'package:open_space_parking/core/cloudinary/data/services/cloudinary_api_service.dart';
import 'package:open_space_parking/core/cloudinary/data/services/cloudinary_validation_service.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_asset.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/domain/repositories/cloudinary_repository.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/mongodb/models/transaction_documents.dart';
import 'package:open_space_parking/core/mongodb/repositories/mongo_repositories.dart';
import 'package:open_space_parking/core/services/api/backend_upload_service.dart';

class CloudinaryRepositoryImpl implements CloudinaryRepository {
  CloudinaryRepositoryImpl({
    required CloudinaryApiService apiService,
    required CloudinaryValidationService validationService,
    required DocumentMongoRepository documentRepository,
    BackendUploadService? backendUploadService,
  })  : _apiService = apiService,
        _validationService = validationService,
        _documentRepository = documentRepository,
        _backendUploadService = backendUploadService ?? BackendUploadService();

  final CloudinaryApiService _apiService;
  final CloudinaryValidationService _validationService;
  final DocumentMongoRepository _documentRepository;
  final BackendUploadService _backendUploadService;

  @override
  Future<CloudinaryAsset> uploadFile({
    required List<int> fileBytes,
    required String fileName,
    required CloudinaryFileCategory category,
    required String ownerId,
    required String ownerType,
    String? referenceId,
    UploadProgressCallback? onProgress,
  }) async {
    final validation = await _validationService.validateBytes(
      fileBytes: fileBytes,
      fileName: fileName,
      category: category,
    );

    if (!validation.isValid) {
      throw AppException(validation.errorMessage ?? 'Invalid file.');
    }

    final asset = await _uploadValidatedFile(
      fileBytes: fileBytes,
      fileName: validation.fileName,
      category: category,
      onProgress: onProgress,
    );

    final now = DateTime.now().toUtc();
    final stored = StoredFileDocument(
      id: '',
      createdAt: now,
      updatedAt: now,
      ownerId: ownerId,
      ownerType: ownerType,
      fileName: asset.fileName,
      fileType: validation.mimeType,
      url: asset.url,
      publicId: asset.publicId,
      resourceType: asset.resourceType,
      referenceId: referenceId,
    );

    final saved = await _documentRepository.create(stored);

    return asset.copyWith(mongoDocumentId: saved.id);
  }

  Future<CloudinaryAsset> _uploadValidatedFile({
    required List<int> fileBytes,
    required String fileName,
    required CloudinaryFileCategory category,
    UploadProgressCallback? onProgress,
  }) async {
    if (BackendUploadService.shouldUseBackendUpload) {
      onProgress?.call(0);
      final asset = await _backendUploadService.upload(
        fileBytes: fileBytes,
        fileName: fileName,
        category: category,
      );
      onProgress?.call(1);
      return asset;
    }

    try {
      return await _apiService.upload(
        fileBytes: fileBytes,
        category: category,
        fileName: fileName,
        onProgress: onProgress,
      );
    } on AppException catch (error) {
      if (_shouldFallbackToBackend(error)) {
        onProgress?.call(0);
        final asset = await _backendUploadService.upload(
          fileBytes: fileBytes,
          fileName: fileName,
          category: category,
        );
        onProgress?.call(1);
        return asset;
      }
      rethrow;
    }
  }

  bool _shouldFallbackToBackend(AppException error) {
    final message = error.message.toLowerCase();
    return message.contains('unknown api key') ||
        message.contains('cloudinary is not configured') ||
        message.contains('invalid cloud name') ||
        message.contains('upload preset');
  }

  @override
  Future<void> deleteAsset(CloudinaryAsset asset) async {
    await _deleteStoredFile(
      url: asset.url,
      publicId: asset.publicId,
      resourceType: asset.resourceType,
    );

    if (asset.mongoDocumentId != null && asset.mongoDocumentId!.isNotEmpty) {
      await _documentRepository.softDelete(asset.mongoDocumentId!);
      return;
    }

    final docs = await _documentRepository.findAll(filters: {'url': asset.url});
    for (final doc in docs) {
      await _documentRepository.softDelete(doc.id);
    }
  }

  @override
  Future<void> deleteByUrl(
    String url, {
    String? publicId,
    String? resourceType,
  }) async {
    StoredFileDocument? stored;
    final docs = await _documentRepository.findAll(filters: {'url': url});
    if (docs.isNotEmpty) {
      stored = docs.first;
    }

    var resolvedPublicId = publicId ?? stored?.publicId;
    if ((resolvedPublicId == null || resolvedPublicId.isEmpty) &&
        BackendUploadService.isBackendUploadUrl(url)) {
      resolvedPublicId = BackendUploadService.publicIdFromUrl(url);
    }

    await _deleteStoredFile(
      url: url,
      publicId: resolvedPublicId,
      resourceType: resourceType ?? stored?.resourceType ?? 'image',
    );

    if (stored != null) {
      await _documentRepository.softDelete(stored.id);
    }
  }

  Future<void> _deleteStoredFile({
    required String url,
    String? publicId,
    required String resourceType,
  }) async {
    if (BackendUploadService.isBackendUploadUrl(url)) {
      await _backendUploadService.deleteByPublicId(publicId ?? '');
      return;
    }

    if (EnvironmentConfig.canDeleteFromCloudinary &&
        publicId != null &&
        publicId.isNotEmpty) {
      await _apiService.destroy(
        publicId: publicId,
        resourceType: resourceType,
      );
    }
  }

  @override
  Future<List<CloudinaryAsset>> getAssetsForOwner(String ownerId) async {
    final docs = await _documentRepository.findAll(filters: {'ownerId': ownerId});
    return docs.map(_mapDocumentToAsset).where((a) => a.url.isNotEmpty).toList();
  }

  CloudinaryAsset _mapDocumentToAsset(StoredFileDocument doc) {
    final category = _categoryFromMime(doc.fileType);
    return CloudinaryAsset(
      url: doc.url,
      publicId: doc.publicId,
      resourceType: doc.resourceType,
      format: _formatFromFileName(doc.fileName),
      fileName: doc.fileName,
      bytes: 0,
      category: category,
      mongoDocumentId: doc.id,
    );
  }

  CloudinaryFileCategory _categoryFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return CloudinaryFileCategory.image;
    }
    if (mimeType == 'application/pdf') {
      return CloudinaryFileCategory.pdf;
    }
    return CloudinaryFileCategory.document;
  }

  String _formatFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}
