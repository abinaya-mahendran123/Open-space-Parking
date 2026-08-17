import 'package:equatable/equatable.dart';

class UploadValidationResult extends Equatable {
  const UploadValidationResult.valid({
    required this.fileName,
    required this.extension,
    required this.bytes,
    required this.mimeType,
  }) : isValid = true,
       errorMessage = null;

  const UploadValidationResult.invalid(this.errorMessage)
      : isValid = false,
        fileName = '',
        extension = '',
        bytes = 0,
        mimeType = '';

  final bool isValid;
  final String? errorMessage;
  final String fileName;
  final String extension;
  final int bytes;
  final String mimeType;

  @override
  List<Object?> get props =>
      [isValid, errorMessage, fileName, extension, bytes, mimeType];
}
