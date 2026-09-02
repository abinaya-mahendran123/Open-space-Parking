import 'package:flutter/material.dart';

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/presentation/widgets/cloudinary_upload_tile.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/digilocker_service.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/digilocker_webview_page.dart';

class UploadDocumentsForm extends StatefulWidget {
  const UploadDocumentsForm({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.ownerId,
  });

  final LandOwnerDocuments initial;
  final ValueChanged<LandOwnerDocuments> onChanged;
  final String ownerId;

  @override
  State<UploadDocumentsForm> createState() => UploadDocumentsFormState();
}

class UploadDocumentsFormState extends State<UploadDocumentsForm> {
  late LandOwnerDocuments _documents;
  final _digilockerService = DigiLockerService();

  // DigiLocker flow state
  bool _digilockerLoading = false;
  String? _digilockerError;
  bool _showManualFallback = false;

  // Sandbox / exchange state
  bool _isSandbox = false;
  String? _accessToken;
  List<DigiLockerFile> _availableFiles = [];
  bool _filesFetched = false;

  static const _fields = [
    _DocField(
      label: 'Property Document',
      category: CloudinaryFileCategory.document,
      referenceId: 'property_document',
      getter: _DocGetter.propertyDocument,
    ),
    _DocField(
      label: 'Patta',
      category: CloudinaryFileCategory.document,
      referenceId: 'patta',
      getter: _DocGetter.patta,
    ),
    _DocField(
      label: 'Property Tax',
      category: CloudinaryFileCategory.document,
      referenceId: 'property_tax',
      getter: _DocGetter.propertyTax,
    ),
    _DocField(
      label: 'Local municipality verified certificate',
      category: CloudinaryFileCategory.document,
      referenceId: 'municipality_certificate',
      getter: _DocGetter.municipalityCertificate,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _documents = widget.initial;
    // If already DigiLocker verified, don't show manual fallback
    if (_documents.digilockerVerified) {
      _showManualFallback = false;
    }
  }

  void _update(LandOwnerDocuments docs) {
    setState(() => _documents = docs);
    widget.onChanged(docs);
  }

  bool get isComplete => _documents.isComplete;

  int get _uploadedCount {
    var count = 0;
    if (_documents.propertyDocumentPath != null) count++;
    if (_documents.pattaPath != null) count++;
    if (_documents.propertyTaxPath != null) count++;
    if (_documents.municipalityCertificatePath != null) count++;
    return count;
  }

  String? _urlFor(_DocGetter getter) {
    return switch (getter) {
      _DocGetter.governmentId => _documents.governmentIdPath,
      _DocGetter.propertyDocument => _documents.propertyDocumentPath,
      _DocGetter.patta => _documents.pattaPath,
      _DocGetter.propertyTax => _documents.propertyTaxPath,
      _DocGetter.municipalityCertificate => _documents.municipalityCertificatePath,
    };
  }

  void _onUrlChanged(_DocGetter getter, String? url) {
    final updated = switch (getter) {
      _DocGetter.governmentId => _documents.copyWith(governmentIdPath: url),
      _DocGetter.propertyDocument =>
        _documents.copyWith(propertyDocumentPath: url),
      _DocGetter.patta => _documents.copyWith(pattaPath: url),
      _DocGetter.propertyTax => _documents.copyWith(propertyTaxPath: url),
      _DocGetter.municipalityCertificate =>
        _documents.copyWith(municipalityCertificatePath: url),
    };
    _update(updated);
  }

  // ── DigiLocker flow ─────────────────────────────────────────────────────────

  Future<void> _startDigiLockerFlow() async {
    setState(() {
      _digilockerLoading = true;
      _digilockerError = null;
      _filesFetched = false;
      _availableFiles = [];
    });

    try {
      final launch = await _digilockerService.getAuthLaunch();
      _isSandbox = launch.isSandbox;

      if (!mounted) return;

      final result = await Navigator.of(context).push<DigiLockerWebViewResult>(
        MaterialPageRoute(
          builder: (_) => DigiLockerWebViewPage(
            initialUrl: launch.url,
            isSandbox: launch.isSandbox,
            redirectUriPrefix:
                launch.isSandbox ? null : launch.redirectUri,
            expectedState: launch.isSandbox ? null : launch.state,
          ),
        ),
      );

      if (!mounted) return;

      if (launch.isSandbox) {
        setState(() {
          _showManualFallback = true;
          _digilockerError = null;
        });
        if (result?.completed == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Documents added in DigiLocker? Upload your property files below.',
              ),
            ),
          );
        }
        return;
      }

      if (result == null) return;

      if (result.errorMessage != null) {
        setState(() => _digilockerError = result.errorMessage);
        return;
      }

      if (result.isSuccess) {
        await _exchangeCode(result.authorizationCode!);
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _digilockerError = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _digilockerError =
              'DigiLocker connection failed. Try manual upload.',
        );
      }
    } finally {
      if (mounted) setState(() => _digilockerLoading = false);
    }
  }

  Future<void> _exchangeCode(String code, {bool isMock = false}) async {
    setState(() => _digilockerLoading = true);
    try {
      final exchanged = await _digilockerService.exchangeCode(
        code,
        isMock: isMock || _isSandbox,
      );
      _accessToken = exchanged.accessToken;

      if (exchanged.files.isEmpty) {
        // No land documents found — prompt manual upload
        setState(() {
          _showManualFallback = true;
          _digilockerError =
              'No property documents found in your DigiLocker account. '
              'Please upload your documents manually below.';
        });
        return;
      }

      setState(() {
        _availableFiles = exchanged.files;
        _filesFetched = true;
      });
    } on AppException catch (e) {
      setState(() => _digilockerError = e.message);
    } finally {
      if (mounted) setState(() => _digilockerLoading = false);
    }
  }

  Future<void> _selectDocument(DigiLockerFile file) async {
    if (_accessToken == null) return;
    setState(() {
      _digilockerLoading = true;
      _digilockerError = null;
    });
    try {
      final doc = await _digilockerService.fetchDocument(
        _accessToken!,
        file.uri,
        isMock: _isSandbox,
      );

      // Store all DigiLocker data into the documents entity
      final updated = _documents.copyWith(
        digilockerVerified: true,
        digilockerOwnerName: doc.ownerName,
        digilockerSurveyNumber: doc.surveyNumber,
        digilockerLandArea: doc.landArea,
        digilockerDistrict: doc.district,
        digilockerDocumentType: doc.documentType,
        digilockerVerificationUrl: doc.verificationUrl,
        digilockerIssuedBy: doc.issuedBy,
        digilockerIssuedOn: doc.issuedOn,
        verificationMethod: DocumentVerificationMethod.digilocker,
      );
      _update(updated);

      setState(() {
        _filesFetched = false;
        _availableFiles = [];
      });
    } on AppException catch (e) {
      setState(() => _digilockerError = e.message);
    } finally {
      if (mounted) setState(() => _digilockerLoading = false);
    }
  }

  void _clearDigiLocker() {
    final updated = _documents.copyWith(
      digilockerVerified: false,
      digilockerOwnerName: null,
      digilockerSurveyNumber: null,
      digilockerLandArea: null,
      digilockerDistrict: null,
      digilockerDocumentType: null,
      digilockerVerificationUrl: null,
      digilockerIssuedBy: null,
      digilockerIssuedOn: null,
      verificationMethod: null,
    );
    _update(updated);
    setState(() {
      _accessToken = null;
      _filesFetched = false;
      _availableFiles = [];
      _digilockerError = null;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── DigiLocker verified banner ──────────────────────────────────────
        if (_documents.digilockerVerified) ...[
          _DigiLockerVerifiedCard(
            documents: _documents,
            onClear: _clearDigiLocker,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showManualFallback = !_showManualFallback),
              icon: Icon(
                _showManualFallback
                    ? Icons.expand_less
                    : Icons.upload_file_outlined,
                size: 18,
              ),
              label: Text(
                _showManualFallback
                    ? 'Hide manual uploads'
                    : 'Also upload manual documents (optional)',
              ),
            ),
          ),
        ] else ...[
          // ── DigiLocker CTA card ───────────────────────────────────────────
          _DigiLockerCtaCard(
            isLoading: _digilockerLoading,
            error: _digilockerError,
            onTap: _startDigiLockerFlow,
          ),

          // ── Document picker after exchange ────────────────────────────────
          if (_filesFetched && _availableFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DigiLockerFileList(
              files: _availableFiles,
              isLoading: _digilockerLoading,
              onSelect: _selectDocument,
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or upload manually',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() => _showManualFallback = !_showManualFallback),
            child: Text(_showManualFallback ? 'Hide manual upload' : 'Upload documents manually'),
          ),
        ],

        // ── Manual upload section ─────────────────────────────────────────
        if (_showManualFallback || !_documents.digilockerVerified) ...[
          if (_showManualFallback || true) ...[
            if (_showManualFallback) ...[
              const SizedBox(height: 12),
              _manualProgressCard(context, colorScheme),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 8),
              _manualProgressCard(context, colorScheme),
              const SizedBox(height: 16),
            ],
            for (var i = 0; i < _fields.length; i++)
              CloudinaryUploadTile(
                stepNumber: i + 1,
                label: _fields[i].label,
                fileUrl: _urlFor(_fields[i].getter),
                category: _fields[i].category,
                ownerId: widget.ownerId,
                ownerType: 'land_owner',
                referenceId: _fields[i].referenceId,
                onUrlChanged: (url) => _onUrlChanged(_fields[i].getter, url),
              ),
          ],
        ],
      ],
    );
  }

  Widget _manualProgressCard(BuildContext context, ColorScheme colorScheme) {
    final total = _fields.length;
    final uploaded = _uploadedCount;
    final progress = total > 0 ? uploaded / total : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  uploaded == total ? Icons.check_circle : Icons.info_outline,
                  color: uploaded == total
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    uploaded == total
                        ? 'All documents uploaded'
                        : '$uploaded of $total documents uploaded',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Upload each document below. You'll see the file name and a green check when it's ready.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DigiLockerCtaCard extends StatelessWidget {
  const _DigiLockerCtaCard({
    required this.isLoading,
    required this.error,
    required this.onTap,
  });

  final bool isLoading;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.verified_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify via DigiLocker',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Instant government-certified verification',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Open DigiLocker to log in with your Aadhaar and upload or share '
              'your Patta or property documents from the government database.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isLoading ? null : onTap,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.open_in_new, size: 18),
              label: Text(isLoading ? 'Connecting to DigiLocker...' : 'Open DigiLocker'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DigiLockerFileList extends StatelessWidget {
  const _DigiLockerFileList({
    required this.files,
    required this.isLoading,
    required this.onSelect,
  });

  final List<DigiLockerFile> files;
  final bool isLoading;
  final ValueChanged<DigiLockerFile> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select your property document',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'These documents were found in your DigiLocker account.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ...files.map(
              (file) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(file.name),
                subtitle: Text(file.issuer),
                trailing: FilledButton.tonal(
                  onPressed: isLoading ? null : () => onSelect(file),
                  child: const Text('Select'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigiLockerVerifiedCard extends StatelessWidget {
  const _DigiLockerVerifiedCard({
    required this.documents,
    required this.onClear,
  });

  final LandOwnerDocuments documents;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'DigiLocker Verified',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove verification',
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove DigiLocker Verification?'),
                      content: const Text(
                        'This will remove the verified document data. '
                        'You will need to upload documents manually.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ).then((confirmed) {
                    if (confirmed == true) onClear();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (documents.digilockerDocumentType?.isNotEmpty == true)
              _Row('Document Type', documents.digilockerDocumentType!),
            if (documents.digilockerOwnerName?.isNotEmpty == true)
              _Row('Owner Name', documents.digilockerOwnerName!),
            if (documents.digilockerSurveyNumber?.isNotEmpty == true)
              _Row('Survey Number', documents.digilockerSurveyNumber!),
            if (documents.digilockerLandArea?.isNotEmpty == true)
              _Row('Land Area', documents.digilockerLandArea!),
            if (documents.digilockerDistrict?.isNotEmpty == true)
              _Row('District', documents.digilockerDistrict!),
            if (documents.digilockerIssuedBy?.isNotEmpty == true)
              _Row('Issued By', documents.digilockerIssuedBy!),
            if (documents.digilockerIssuedOn?.isNotEmpty == true)
              _Row('Issued On', documents.digilockerIssuedOn!),
            if (documents.isMock == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sandbox / Test Mode — mock data',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade800,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Verified by Government of India — DigiLocker',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── Private enums ─────────────────────────────────────────────────────────────

enum _DocGetter {
  governmentId,
  propertyDocument,
  patta,
  propertyTax,
  municipalityCertificate,
}

class _DocField {
  const _DocField({
    required this.label,
    required this.category,
    required this.referenceId,
    required this.getter,
  });

  final String label;
  final CloudinaryFileCategory category;
  final String referenceId;
  final _DocGetter getter;
}

extension on LandOwnerDocuments {
  bool? get isMock => digilockerVerificationUrl?.contains('sandbox') == true;
}
