import 'package:flutter/material.dart';

import 'package:open_space_parking/core/cloudinary/domain/entities/upload_progress.dart';

class CloudinaryUploadProgressBar extends StatelessWidget {
  const CloudinaryUploadProgressBar({
    super.key,
    required this.progress,
  });

  final UploadProgress progress;

  @override
  Widget build(BuildContext context) {
    if (!progress.isBusy && progress.status != UploadStatus.completed) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress.status == UploadStatus.completed ? 1 : progress.progress,
          minHeight: 4,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 4),
        Text(
          _statusLabel(progress),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: progress.status == UploadStatus.failed
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
        ),
        if (progress.errorMessage != null) ...[
          const SizedBox(height: 2),
          Text(
            progress.errorMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
          ),
        ],
      ],
    );
  }

  String _statusLabel(UploadProgress progress) {
    return switch (progress.status) {
      UploadStatus.validating => 'Validating file…',
      UploadStatus.uploading =>
        'Uploading ${(progress.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
      UploadStatus.completed => 'Upload complete',
      UploadStatus.failed => 'Upload failed',
      UploadStatus.idle => '',
    };
  }
}
