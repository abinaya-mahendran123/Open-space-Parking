import 'package:equatable/equatable.dart';

enum UploadStatus { idle, validating, uploading, completed, failed }

class UploadProgress extends Equatable {
  const UploadProgress({
    this.status = UploadStatus.idle,
    this.progress = 0,
    this.errorMessage,
  });

  final UploadStatus status;
  final double progress;
  final String? errorMessage;

  bool get isBusy =>
      status == UploadStatus.validating || status == UploadStatus.uploading;

  UploadProgress copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UploadProgress(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, progress, errorMessage];
}
