import 'dart:io';

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/upload_validation_result.dart';

class CloudinaryValidationService {
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxPdfBytes = 20 * 1024 * 1024;
  static const int maxDocumentBytes = 15 * 1024 * 1024;

  static const Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  };

  static const Set<String> pdfExtensions = {'pdf'};

  static const Set<String> documentExtensions = {
    'pdf',
    'doc',
    'docx',
    'txt',
    'jpg',
    'jpeg',
    'png',
  };

  Future<UploadValidationResult> validateBytes({
    required List<int> fileBytes,
    required String fileName,
    required CloudinaryFileCategory category,
  }) async {
    if (fileName.trim().isEmpty) {
      return const UploadValidationResult.invalid('File name is required.');
    }

    final extension = _extensionFromFileName(fileName);
    if (extension.isEmpty) {
      return const UploadValidationResult.invalid('File must have an extension.');
    }

    if (category != CloudinaryFileCategory.any) {
      final allowed = _allowedExtensions(category);
      if (!allowed.contains(extension)) {
        return UploadValidationResult.invalid(
          'Invalid file type. Allowed: ${allowed.join(', ')}',
        );
      }
    }

    final bytes = fileBytes.length;
    final maxBytes = _maxBytes(category);
    if (bytes <= 0) {
      return const UploadValidationResult.invalid('File is empty.');
    }
    if (bytes > maxBytes) {
      return UploadValidationResult.invalid(
        'File exceeds ${_formatSize(maxBytes)} limit.',
      );
    }

    return UploadValidationResult.valid(
      fileName: fileName,
      extension: extension,
      bytes: bytes,
      mimeType: _mimeType(extension),
    );
  }

  Future<UploadValidationResult> validate({
    required String localPath,
    required CloudinaryFileCategory category,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return const UploadValidationResult.invalid('File not found.');
    }

    final fileName = _fileNameFromPath(localPath);
    final extension = _extensionFromFileName(fileName);
    if (extension.isEmpty) {
      return const UploadValidationResult.invalid('File must have an extension.');
    }

    if (category != CloudinaryFileCategory.any) {
      final allowed = _allowedExtensions(category);
      if (!allowed.contains(extension)) {
        return UploadValidationResult.invalid(
          'Invalid file type. Allowed: ${allowed.join(', ')}',
        );
      }
    }

    final bytes = await file.length();
    final maxBytes = _maxBytes(category);
    if (bytes <= 0) {
      return const UploadValidationResult.invalid('File is empty.');
    }
    if (bytes > maxBytes) {
      return UploadValidationResult.invalid(
        'File exceeds ${_formatSize(maxBytes)} limit.',
      );
    }

    return UploadValidationResult.valid(
      fileName: fileName,
      extension: extension,
      bytes: bytes,
      mimeType: _mimeType(extension),
    );
  }

  Set<String> _allowedExtensions(CloudinaryFileCategory category) {
    return switch (category) {
      CloudinaryFileCategory.image => imageExtensions,
      CloudinaryFileCategory.pdf => pdfExtensions,
      CloudinaryFileCategory.document => documentExtensions,
      CloudinaryFileCategory.any => const {},
    };
  }

  int _maxBytes(CloudinaryFileCategory category) {
    return switch (category) {
      CloudinaryFileCategory.image => maxImageBytes,
      CloudinaryFileCategory.pdf => maxPdfBytes,
      CloudinaryFileCategory.document => maxDocumentBytes,
      CloudinaryFileCategory.any => maxPdfBytes,
    };
  }

  String _fileNameFromPath(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }

  String _extensionFromFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String _extensionFromPath(String path) {
    return _extensionFromFileName(_fileNameFromPath(path));
  }

  String _mimeType(String extension) {
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
