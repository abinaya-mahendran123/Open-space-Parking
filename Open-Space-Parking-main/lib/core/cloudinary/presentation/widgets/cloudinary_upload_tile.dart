import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/upload_progress.dart';
import 'package:open_space_parking/core/cloudinary/presentation/providers/cloudinary_providers.dart';
import 'package:open_space_parking/core/cloudinary/presentation/widgets/cloudinary_upload_progress.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/utils/file_bytes_reader.dart';

class CloudinaryUploadTile extends ConsumerStatefulWidget {
  const CloudinaryUploadTile({
    super.key,
    required this.label,
    required this.fileUrl,
    required this.category,
    required this.ownerId,
    required this.ownerType,
    required this.onUrlChanged,
    this.referenceId,
    this.subtitle,
    this.stepNumber,
  });

  final String label;
  final String? fileUrl;
  final CloudinaryFileCategory category;
  final String ownerId;
  final String ownerType;
  final ValueChanged<String?> onUrlChanged;
  final String? referenceId;
  final String? subtitle;
  final int? stepNumber;

  @override
  ConsumerState<CloudinaryUploadTile> createState() =>
      _CloudinaryUploadTileState();
}

class _CloudinaryUploadTileState extends ConsumerState<CloudinaryUploadTile> {
  UploadProgress _progress = const UploadProgress();
  bool _isDeleting = false;
  String? _lastPickedFileName;

  Set<String> get _allowedExtensions {
    return switch (widget.category) {
      CloudinaryFileCategory.image => {'jpg', 'jpeg', 'png', 'webp', 'gif'},
      CloudinaryFileCategory.pdf => {'pdf'},
      CloudinaryFileCategory.document =>
        {'pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'},
      CloudinaryFileCategory.any => const {},
    };
  }

  bool get _acceptsAnyFileType =>
      widget.category == CloudinaryFileCategory.any;

  bool get _hasFile =>
      widget.fileUrl != null && widget.fileUrl!.isNotEmpty;

  String get _displayFileName {
    if (_lastPickedFileName != null && _lastPickedFileName!.isNotEmpty) {
      return _lastPickedFileName!;
    }
    final url = widget.fileUrl;
    if (url == null) return '';
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return Uri.decodeComponent(uri.pathSegments.last);
    }
    return 'Uploaded file';
  }

  Future<void> _pickAndUpload() async {
    if (_progress.isBusy || widget.ownerId.isEmpty) return;

    final result = _acceptsAnyFileType
        ? await FilePicker.platform.pickFiles(
            type: FileType.any,
            withData: kIsWeb,
          )
        : await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: _allowedExtensions.toList(),
            withData: kIsWeb,
          );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.name.isEmpty) return;

    late List<int> fileBytes;
    if (kIsWeb) {
      if (picked.bytes == null || picked.bytes!.isEmpty) return;
      fileBytes = picked.bytes!;
    } else {
      final path = picked.path;
      if (path == null || path.isEmpty) return;
      fileBytes = await readFileBytes(path);
    }

    _lastPickedFileName = picked.name;

    setState(() {
      _progress = const UploadProgress(
        status: UploadStatus.validating,
        progress: 0,
      );
    });

    try {
      setState(() {
        _progress = _progress.copyWith(status: UploadStatus.uploading);
      });

      final asset = await ref.read(cloudinaryRepositoryProvider).uploadFile(
            fileBytes: fileBytes,
            fileName: picked.name,
            category: widget.category,
            ownerId: widget.ownerId,
            ownerType: widget.ownerType,
            referenceId: widget.referenceId,
            onProgress: (value) {
              if (mounted) {
                setState(() {
                  _progress = _progress.copyWith(progress: value);
                });
              }
            },
          );

      if (mounted) {
        setState(() {
          _progress = const UploadProgress(
            status: UploadStatus.completed,
            progress: 1,
          );
        });
        widget.onUrlChanged(asset.url);
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _progress = UploadProgress(
            status: UploadStatus.failed,
            errorMessage: e.message,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _progress = const UploadProgress(
            status: UploadStatus.failed,
            errorMessage: 'Upload failed. Please try again.',
          );
        });
      }
    }
  }

  Future<void> _delete() async {
    final url = widget.fileUrl;
    if (url == null || _isDeleting) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(cloudinaryRepositoryProvider).deleteByUrl(url);
      if (mounted) {
        widget.onUrlChanged(null);
        _lastPickedFileName = null;
        setState(() => _progress = const UploadProgress());
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        setState(() {
          _progress = UploadProgress(
            status: UploadStatus.failed,
            errorMessage: e.message,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove file. Please try again.')),
        );
        setState(() {
          _progress = const UploadProgress(
            status: UploadStatus.failed,
            errorMessage: 'Could not remove file. Please try again.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String _statusText() {
    if (_progress.status == UploadStatus.uploading) {
      final pct = (_progress.progress * 100).clamp(0, 100).toInt();
      return 'Uploading… $pct%';
    }
    if (_progress.status == UploadStatus.validating) {
      return 'Validating file…';
    }
    if (_progress.status == UploadStatus.failed) {
      return _progress.errorMessage ?? 'Upload failed';
    }
    if (_hasFile) {
      return 'Uploaded: $_displayFileName';
    }
    return widget.subtitle ?? _subtitleForCategory(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUploading = _progress.isBusy;
    final isFailed = _progress.status == UploadStatus.failed;
    final isComplete = _hasFile && !isUploading && !isFailed;

    final borderColor = isComplete
        ? colorScheme.primary
        : isFailed
            ? colorScheme.error
            : isUploading
                ? colorScheme.primary.withValues(alpha: 0.6)
                : colorScheme.outlineVariant;

    final leadingBackground = isComplete
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    final leadingIcon = isComplete
        ? Icons.check_circle
        : isUploading
            ? Icons.cloud_upload_outlined
            : Icons.upload_file_outlined;

    final leadingColor = isComplete
        ? colorScheme.primary
        : isFailed
            ? colorScheme.error
            : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isComplete
            ? colorScheme.primaryContainer.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isUploading ? null : (_hasFile ? null : _pickAndUpload),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: isComplete ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: leadingBackground,
                      child: isUploading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.primary,
                              ),
                            )
                          : Icon(leadingIcon, color: leadingColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widget.stepNumber != null) ...[
                                Text(
                                  '${widget.stepNumber}. ',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: colorScheme.primary),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  widget.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (isComplete)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Done',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                )
                              else if (!isUploading)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Required',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onErrorContainer,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusText(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isFailed
                                      ? colorScheme.error
                                      : isComplete
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isUploading || isFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: CloudinaryUploadProgressBar(progress: _progress),
                  ),
                if (_hasFile && !isUploading) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickAndUpload,
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Replace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _isDeleting ? null : _delete,
                          icon: _isDeleting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.error,
                                  ),
                                )
                              : Icon(Icons.delete_outline,
                                  size: 18, color: colorScheme.error),
                          label: Text(
                            'Remove',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (!isUploading && !isFailed) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _pickAndUpload,
                    icon: const Icon(Icons.add),
                    label: const Text('Choose File'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleForCategory(CloudinaryFileCategory category) {
    return switch (category) {
      CloudinaryFileCategory.image => 'No file yet · JPG, PNG, WEBP',
      CloudinaryFileCategory.pdf => 'No file yet · PDF only',
      CloudinaryFileCategory.document =>
        'No file yet · PDF, DOC, DOCX, TXT, JPG, PNG',
      CloudinaryFileCategory.any => 'No file yet · Any file type',
    };
  }
}
