import 'package:equatable/equatable.dart';

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';

class CloudinaryAsset extends Equatable {
  const CloudinaryAsset({
    required this.url,
    required this.publicId,
    required this.resourceType,
    required this.format,
    required this.fileName,
    required this.bytes,
    required this.category,
    this.mongoDocumentId,
  });

  final String url;
  final String publicId;
  final String resourceType;
  final String format;
  final String fileName;
  final int bytes;
  final CloudinaryFileCategory category;
  final String? mongoDocumentId;

  bool get isImage => category == CloudinaryFileCategory.image;

  bool get isPdf =>
      category == CloudinaryFileCategory.pdf || format.toLowerCase() == 'pdf';

  factory CloudinaryAsset.fromUploadResponse(
    Map<String, dynamic> json, {
    required CloudinaryFileCategory category,
    String? fileName,
  }) {
    return CloudinaryAsset(
      url: json['secure_url'] as String? ?? json['url'] as String? ?? '',
      publicId: json['public_id'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? 'auto',
      format: json['format'] as String? ?? '',
      fileName: fileName ??
          json['original_filename'] as String? ??
          json['public_id'] as String? ??
          'file',
      bytes: json['bytes'] as int? ?? 0,
      category: category,
    );
  }

  CloudinaryAsset copyWith({String? mongoDocumentId}) {
    return CloudinaryAsset(
      url: url,
      publicId: publicId,
      resourceType: resourceType,
      format: format,
      fileName: fileName,
      bytes: bytes,
      category: category,
      mongoDocumentId: mongoDocumentId ?? this.mongoDocumentId,
    );
  }

  @override
  List<Object?> get props => [
        url,
        publicId,
        resourceType,
        format,
        fileName,
        bytes,
        category,
        mongoDocumentId,
      ];
}
