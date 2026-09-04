import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/upload_progress.dart';
import 'package:open_space_parking/core/cloudinary/presentation/providers/cloudinary_providers.dart';
import 'package:open_space_parking/core/cloudinary/presentation/widgets/cloudinary_upload_progress.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/government_id_ocr_service.dart';
import 'package:open_space_parking/core/utils/camera_access.dart';
import 'package:open_space_parking/core/utils/file_bytes_reader.dart';
import 'package:open_space_parking/core/utils/ocr_image_bytes.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/government_id_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/aadhaar_ocr_provider.dart';

Uint8List _copyToUint8List(List<int> bytes) => Uint8List.fromList(bytes);

class GovernmentIdOwnerDetailsForm extends ConsumerStatefulWidget {
  const GovernmentIdOwnerDetailsForm({
    super.key,
    required this.initial,
    required this.onSave,
    required this.ownerId,
    this.accountEmail,
  });

  final OwnerDetails? initial;
  final ValueChanged<OwnerDetails> onSave;
  final String ownerId;
  final String? accountEmail;

  @override
  ConsumerState<GovernmentIdOwnerDetailsForm> createState() =>
      GovernmentIdOwnerDetailsFormState();
}

class GovernmentIdOwnerDetailsFormState
    extends ConsumerState<GovernmentIdOwnerDetailsForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _idNumberController;

  String? _uploadedUrl;
  Uint8List? _previewBytes;
  Uint8List? _ocrImageBytes;
  bool _isPdfUpload = false;
  UploadProgress _uploadProgress = const UploadProgress();
  bool _isDeleting = false;
  String? _extractError;

  bool get _hasFile => _uploadedUrl != null && _uploadedUrl!.isNotEmpty;
  bool get _isUploading => _uploadProgress.isBusy;

  bool _isOcrRunning(WidgetRef ref) {
    final ocr = ref.watch(aadhaarOcrProvider);
    return ocr.isRunning && ocr.uploadUrl == _uploadedUrl;
  }

  bool _isWrongDocumentMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('does not look like an aadhaar') ||
        lower.contains('please upload your aadhaar card only') ||
        lower.contains('looks like a pan') ||
        lower.contains('looks like a driving') ||
        lower.contains('looks like a voter') ||
        lower.contains('looks like a passport');
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _uploadedUrl = initial?.governmentIdFrontPath;
    _isPdfUpload =
        (_uploadedUrl?.toLowerCase().contains('.pdf') ?? false) ||
        (_uploadedUrl?.toLowerCase().contains('/raw/upload/') ?? false);
    _nameController = TextEditingController(text: initial?.fullName ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _addressController = TextEditingController(text: initial?.address ?? '');
    _idNumberController = TextEditingController(
      text: initial?.governmentIdNumber ?? initial?.aadhaarNumber ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  static final ImagePicker _imagePicker = ImagePicker();

  Future<void> _captureFromCamera() async {
    if (_isUploading || widget.ownerId.isEmpty) return;

    if (!kIsWeb) {
      final permission = await CameraAccess.ensure(context: context);
      if (permission != CameraPermissionStatus.granted) {
        if (!mounted) return;
        setState(() {
          _extractError = CameraAccess.messageFor(permission);
        });
        return;
      }
    }

    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) return;
      final ocrBytes = await downscaleForOcr(bytes);

      final name = photo.name.trim().isNotEmpty
          ? photo.name
          : 'aadhaar_camera_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _uploadSelectedFile(
        fileBytes: ocrBytes,
        fileName: name,
        previewBytes: ocrBytes,
        ocrBytes: ocrBytes,
        isPdf: false,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied' ||
          e.message?.toLowerCase().contains('permission') == true;
      setState(() {
        _extractError = denied
            ? 'Camera access denied. Allow camera permission and try again.'
            : 'Could not open the camera. Please try again or choose a file.';
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _extractError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _extractError = kIsWeb
            ? 'Could not open the camera. Allow camera access in your browser, or choose a file instead.'
            : 'Could not open the camera. Allow camera permission and try again.';
      });
    }
  }

  Future<void> _pickFromFiles() async {
    if (_isUploading || widget.ownerId.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.name.isEmpty) return;

    final extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : '';
    final isPdf = extension == 'pdf';

    late List<int> fileBytes;
    Uint8List? previewBytes;

    if (kIsWeb) {
      if (picked.bytes == null || picked.bytes!.isEmpty) return;
      fileBytes = picked.bytes!;
      if (!isPdf) {
        previewBytes = await downscaleForOcr(picked.bytes!);
      }
    } else {
      final path = picked.path;
      if (path == null || path.isEmpty) return;
      fileBytes = await readFileBytes(path);
      if (!isPdf) {
        previewBytes = await compute(_copyToUint8List, fileBytes);
        previewBytes = await downscaleForOcr(previewBytes!);
      }
    }

    await _uploadSelectedFile(
      fileBytes: fileBytes,
      fileName: picked.name,
      previewBytes: previewBytes,
      ocrBytes: previewBytes,
      isPdf: isPdf,
    );
  }

  Future<void> _uploadSelectedFile({
    required List<int> fileBytes,
    required String fileName,
    required Uint8List? previewBytes,
    Uint8List? ocrBytes,
    required bool isPdf,
  }) async {
    final category =
        isPdf ? CloudinaryFileCategory.pdf : CloudinaryFileCategory.image;

    setState(() {
      _previewBytes = previewBytes;
      _ocrImageBytes = isPdf ? null : (ocrBytes ?? previewBytes);
      _isPdfUpload = isPdf;
      _uploadProgress = const UploadProgress(
        status: UploadStatus.uploading,
        progress: 0,
      );
      _extractError = null;
    });

    try {
      final asset = await ref.read(cloudinaryRepositoryProvider).uploadFile(
            fileBytes: fileBytes,
            fileName: fileName,
            category: category,
            ownerId: widget.ownerId,
            ownerType: 'land_owner',
            referenceId: 'aadhaar_card',
            onProgress: (value) {
              if (mounted) {
                setState(() {
                  _uploadProgress = _uploadProgress.copyWith(progress: value);
                });
              }
            },
          );

      if (!mounted) return;

      setState(() {
        _uploadedUrl = asset.url;
        _uploadProgress = const UploadProgress(
          status: UploadStatus.completed,
          progress: 1,
        );
      });

      _startOcrExtract();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadProgress = UploadProgress(
          status: UploadStatus.failed,
          errorMessage: e.message,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadProgress = const UploadProgress(
          status: UploadStatus.failed,
          errorMessage: 'Upload failed. Please try again.',
        );
      });
    }
  }

  Future<void> _showPickerOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Upload Aadhaar Card',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload a clear PNG photo or PDF of your Aadhaar card',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.camera_alt_outlined)),
                title: const Text('Use Camera'),
                subtitle: const Text(
                  kIsWeb
                      ? 'Opens your device or browser camera to take a photo'
                      : 'Opens the phone camera to capture your Aadhaar card',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureFromCamera();
                },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library_outlined)),
                title: const Text('Choose from Files'),
                subtitle: const Text('PNG, JPG, WEBP, or PDF'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromFiles();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _applyOcrResult(GovernmentIdExtractionResult result) {
    if (result.fullName.isNotEmpty) {
      _nameController.text = result.fullName;
    }
    if (result.phone.isNotEmpty &&
        RegExp(r'^[6-9]\d{9}$').hasMatch(result.phone)) {
      _phoneController.text = result.phone;
    }
    if (result.address.isNotEmpty) {
      _addressController.text = result.address;
    }
    final idNumber = (result.aadhaarNumber?.isNotEmpty == true
            ? result.aadhaarNumber!
            : result.governmentIdNumber)
        .replaceAll(RegExp(r'\D'), '');
    if (idNumber.length == 12) {
      _idNumberController.text = idNumber;
    }

    final isBackSide = result.detectedSide == 'back' ||
        result.ocrAccepted &&
            result.fullName.isEmpty &&
            result.address.isNotEmpty;
    final hasValidId =
        _idNumberController.text.replaceAll(RegExp(r'\D'), '').length == 12;
    final hasAddress = _addressController.text.trim().length >= 12;

    if (result.ocrAccepted ||
        (isBackSide && hasValidId && hasAddress) ||
        (isBackSide && hasAddress && _nameController.text.trim().isNotEmpty)) {
      setState(() => _extractError = null);
      return;
    }

    final missing = <String>[];
    if (_nameController.text.trim().isEmpty && !isBackSide) {
      missing.add('name');
    }
    if (_addressController.text.trim().isEmpty) missing.add('address');
    if (!hasValidId) missing.add('Aadhaar number');
    if (missing.isNotEmpty) {
      setState(() {
        _extractError =
            'Could not read ${missing.join(', ')} clearly. '
            'Use a clear photo of the full card (not PDF). '
            'You can type any missing fields below and Continue.';
      });
    } else {
      setState(() => _extractError = null);
    }
  }

  void _startOcrExtract() {
    if (_uploadedUrl == null || _uploadedUrl!.isEmpty) return;

    setState(() => _extractError = null);

    ref.read(aadhaarOcrProvider.notifier).startExtract(
          uploadUrl: _uploadedUrl!,
          imageBytes: _ocrImageBytes ?? _previewBytes,
        );
  }

  void _handleOcrState(AadhaarOcrState ocr) {
    if (ocr.uploadUrl != _uploadedUrl) return;
    if (ocr.isRunning) return;

    if (ocr.error != null) {
      if (_isWrongDocumentMessage(ocr.error!)) {
        _nameController.clear();
        _addressController.clear();
        _idNumberController.clear();
        _phoneController.clear();
      }
      setState(() => _extractError = ocr.error);
      return;
    }

    final result = ocr.result;
    if (result == null) return;

    _applyOcrResult(result);

    final details = ownerDetailsFromOcr(
      result: result,
      uploadedUrl: _uploadedUrl!,
      accountEmail: widget.accountEmail,
    );
    widget.onSave(details);
  }

  Future<void> _removeUpload() async {
    final url = _uploadedUrl;
    if (url == null || _isDeleting) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(cloudinaryRepositoryProvider).deleteByUrl(url);
      if (mounted) {
        setState(() {
          _uploadedUrl = null;
          _previewBytes = null;
          _ocrImageBytes = null;
          _isPdfUpload = false;
          _uploadProgress = const UploadProgress();
          _extractError = null;
          _isDeleting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  bool validateAndSave() {
    if (!_hasFile) {
      setState(() {
        _extractError = 'Please upload your Aadhaar card as a PNG image or PDF.';
      });
      return false;
    }
    if (!_formKey.currentState!.validate()) return false;

    final idNumber = _idNumberController.text.trim().replaceAll(' ', '');
    final email = ProfilePrefill.firstNonEmpty([
      ProfilePrefill.realEmail(widget.accountEmail),
      widget.accountEmail,
    ]);

    widget.onSave(
      OwnerDetails(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: email,
        address: _addressController.text.trim(),
        aadhaarNumber: idNumber,
        governmentIdType: GovernmentIdType.aadhaar,
        governmentIdNumber: idNumber,
        governmentIdFrontPath: _uploadedUrl,
        governmentIdBackPath: _uploadedUrl,
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ocr = ref.watch(aadhaarOcrProvider);
    ref.listen<AadhaarOcrState>(aadhaarOcrProvider, (previous, next) {
      if (!mounted) return;
      if (next.uploadUrl != _uploadedUrl) return;
      if (next.isRunning) return;
      if (previous?.jobId == next.jobId && previous?.isRunning == next.isRunning) {
        return;
      }
      _handleOcrState(next);
    });

    if (!ocr.isRunning &&
        ocr.result != null &&
        ocr.uploadUrl == _uploadedUrl &&
        _nameController.text.isEmpty &&
        _addressController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleOcrState(ocr);
      });
    }

    final isExtracting = _isOcrRunning(ref);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upload a clear Aadhaar photo or PDF. Details fill in automatically.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          _AadhaarUploadCard(
            hasFile: _hasFile,
            isUploading: _isUploading,
            isDeleting: _isDeleting,
            isExtracting: isExtracting,
            isPdf: _isPdfUpload ||
                (_uploadedUrl?.toLowerCase().contains('.pdf') ?? false),
            previewBytes: _previewBytes,
            uploadedUrl: _uploadedUrl,
            progress: _uploadProgress,
            onUpload: _showPickerOptions,
            onRemove: _removeUpload,
            onRescan: _startOcrExtract,
          ),
          if (_extractError != null) ...[
            const SizedBox(height: 8),
            Text(
              _extractError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
            ),
          ],
          if (_hasFile || _nameController.text.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Review extracted details',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _nameController,
              label: 'Full Name',
              validator: (v) => Validators.requiredField(v, fieldName: 'Name'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
              validator: Validators.mobileNumber,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _addressController,
              label: 'Address',
              validator: (v) => Validators.requiredField(v, fieldName: 'Address'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _idNumberController,
              label: 'Aadhaar Number',
              validator: Validators.aadhaar,
            ),
          ],
        ],
      ),
    );
  }
}

class _AadhaarUploadCard extends StatelessWidget {
  const _AadhaarUploadCard({
    required this.hasFile,
    required this.isUploading,
    required this.isDeleting,
    required this.isExtracting,
    required this.isPdf,
    required this.previewBytes,
    required this.uploadedUrl,
    required this.progress,
    required this.onUpload,
    required this.onRemove,
    required this.onRescan,
  });

  final bool hasFile;
  final bool isUploading;
  final bool isDeleting;
  final bool isExtracting;
  final bool isPdf;
  final Uint8List? previewBytes;
  final String? uploadedUrl;
  final UploadProgress progress;
  final VoidCallback onUpload;
  final VoidCallback onRemove;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFailed = progress.status == UploadStatus.failed;

    final borderColor = hasFile && !isFailed
        ? colorScheme.primary
        : isFailed
            ? colorScheme.error
            : isUploading
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant;

    return Material(
      color: hasFile && !isFailed
          ? colorScheme.primaryContainer.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isUploading || hasFile ? null : onUpload,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: hasFile && !isFailed ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: hasFile && !isFailed
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    child: isUploading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(
                            hasFile && !isFailed
                                ? Icons.check_circle_outline
                                : isFailed
                                    ? Icons.error_outline
                                    : Icons.credit_card_outlined,
                            color: hasFile && !isFailed
                                ? colorScheme.primary
                                : isFailed
                                    ? colorScheme.error
                                    : colorScheme.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Aadhaar Card',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: hasFile && !isFailed
                                    ? colorScheme.primaryContainer
                                    : colorScheme.errorContainer
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                hasFile && !isFailed ? 'Uploaded' : 'Required',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: hasFile && !isFailed
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUploading
                              ? 'Uploading… ${(progress.progress * 100).toInt()}%'
                              : isFailed
                                  ? progress.errorMessage ?? 'Upload failed'
                                  : isExtracting
                                      ? 'Reading ID details…'
                                      : hasFile
                                          ? (isPdf
                                              ? 'PDF uploaded · tap Re-scan if details are missing'
                                              : 'Tap Re-scan if details are missing')
                                          : 'Tap to upload PNG image or PDF',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isFailed
                                    ? colorScheme.error
                                    : colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isUploading || isFailed) ...[
                const SizedBox(height: 12),
                CloudinaryUploadProgressBar(progress: progress),
              ],
              if (isExtracting) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                const Text(
                  'Reading your Aadhaar card… usually a few seconds.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
              if (hasFile && isPdf) ...[
                const SizedBox(height: 14),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aadhaar PDF ready',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ] else if (previewBytes != null && hasFile) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    previewBytes!,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              if (hasFile && !isUploading) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onUpload,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Replace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isExtracting ? null : onRescan,
                        icon: const Icon(Icons.document_scanner_outlined, size: 18),
                        label: const Text('Re-scan'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: isDeleting ? null : onRemove,
                      icon: isDeleting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.error,
                              ),
                            )
                          : Icon(Icons.delete_outline, color: colorScheme.error),
                    ),
                  ],
                ),
              ] else if (!isUploading) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Upload Aadhaar Card'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
