import 'package:flutter/material.dart';

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/presentation/widgets/cloudinary_upload_tile.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/property_document_ocr_service.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';

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
  final _ocrService = PropertyDocumentOcrService();

  final Map<_DocGetter, bool> _verified = {};
  final Map<_DocGetter, bool> _verifying = {};
  final Map<_DocGetter, String?> _errors = {};

  static const _fields = [
    _DocField(
      label: 'Property Document',
      category: CloudinaryFileCategory.document,
      referenceId: 'property_document',
      expectedType: 'property_document',
      getter: _DocGetter.propertyDocument,
    ),
    _DocField(
      label: 'Patta',
      category: CloudinaryFileCategory.document,
      referenceId: 'patta',
      expectedType: 'patta',
      getter: _DocGetter.patta,
    ),
    _DocField(
      label: 'Property Tax',
      category: CloudinaryFileCategory.document,
      referenceId: 'property_tax',
      expectedType: 'property_tax',
      getter: _DocGetter.propertyTax,
    ),
    _DocField(
      label: 'Local municipality verified certificate',
      category: CloudinaryFileCategory.document,
      referenceId: 'municipality_certificate',
      expectedType: 'municipality_certificate',
      getter: _DocGetter.municipalityCertificate,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _documents = widget.initial;
    for (final field in _fields) {
      final url = _urlFor(field.getter);
      // Previously saved URLs still need re-verification in this session.
      _verified[field.getter] = false;
      _verifying[field.getter] = false;
      _errors[field.getter] = null;
      if (url != null && url.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _verifyDocument(field, url);
        });
      }
    }
  }

  void _update(LandOwnerDocuments docs) {
    setState(() => _documents = docs);
    widget.onChanged(docs);
  }

  /// True only when all 4 documents are uploaded AND OCR-verified as the correct type.
  bool get isComplete =>
      _fields.every((f) => _urlFor(f.getter) != null && _verified[f.getter] == true);

  bool get isVerifying => _verifying.values.any((v) => v);

  String? get blockingMessage {
    if (isVerifying) {
      return 'Please wait — verifying uploaded documents.';
    }
    for (final field in _fields) {
      final err = _errors[field.getter];
      if (err != null && err.isNotEmpty) {
        return err;
      }
    }
    for (final field in _fields) {
      if (_urlFor(field.getter) == null) {
        return 'Please upload all 4 required documents.';
      }
      if (_verified[field.getter] != true) {
        return 'Please upload a valid ${field.label}.';
      }
    }
    return null;
  }

  int get _uploadedCount {
    var count = 0;
    for (final field in _fields) {
      if (_urlFor(field.getter) != null && _verified[field.getter] == true) {
        count++;
      }
    }
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

  LandOwnerDocuments _clearUrl(_DocGetter getter) {
    return switch (getter) {
      _DocGetter.governmentId => _documents.copyWith(governmentIdPath: null),
      _DocGetter.propertyDocument =>
        _documents.copyWith(propertyDocumentPath: null),
      _DocGetter.patta => _documents.copyWith(pattaPath: null),
      _DocGetter.propertyTax => _documents.copyWith(propertyTaxPath: null),
      _DocGetter.municipalityCertificate =>
        _documents.copyWith(municipalityCertificatePath: null),
    };
  }

  LandOwnerDocuments _setUrl(_DocGetter getter, String? url) {
    return switch (getter) {
      _DocGetter.governmentId => _documents.copyWith(governmentIdPath: url),
      _DocGetter.propertyDocument =>
        _documents.copyWith(propertyDocumentPath: url),
      _DocGetter.patta => _documents.copyWith(pattaPath: url),
      _DocGetter.propertyTax => _documents.copyWith(propertyTaxPath: url),
      _DocGetter.municipalityCertificate =>
        _documents.copyWith(municipalityCertificatePath: url),
    };
  }

  Future<void> _onUrlChanged(_DocField field, String? url) async {
    if (url == null || url.isEmpty) {
      setState(() {
        _verified[field.getter] = false;
        _verifying[field.getter] = false;
        _errors[field.getter] = null;
      });
      _update(_clearUrl(field.getter));
      return;
    }

    // Keep URL while verifying so the tile shows the file.
    _update(_setUrl(field.getter, url));
    await _verifyDocument(field, url);
  }

  Future<void> _verifyDocument(_DocField field, String url) async {
    setState(() {
      _verifying[field.getter] = true;
      _errors[field.getter] = null;
      _verified[field.getter] = false;
    });

    try {
      final result = await _ocrService.verifyUpload(
        documentUrl: url,
        expectedType: field.expectedType,
      );
      if (!mounted) return;

      if (!result.accepted) {
        setState(() {
          _verifying[field.getter] = false;
          _verified[field.getter] = false;
          _errors[field.getter] = result.message;
        });
        _update(_clearUrl(field.getter));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
        }
        return;
      }

      setState(() {
        _verifying[field.getter] = false;
        _verified[field.getter] = true;
        _errors[field.getter] = null;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying[field.getter] = false;
        _verified[field.getter] = false;
        _errors[field.getter] = e.message;
      });
      _update(_clearUrl(field.getter));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      const message =
          'Could not verify this document. Please upload a clear photo or PDF of the required document.';
      setState(() {
        _verifying[field.getter] = false;
        _verified[field.getter] = false;
        _errors[field.getter] = message;
      });
      _update(_clearUrl(field.getter));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _manualProgressCard(context, colorScheme),
        const SizedBox(height: 16),
        for (var i = 0; i < _fields.length; i++) ...[
          CloudinaryUploadTile(
            stepNumber: i + 1,
            label: _fields[i].label,
            fileUrl: _urlFor(_fields[i].getter),
            category: _fields[i].category,
            ownerId: widget.ownerId,
            ownerType: 'land_owner',
            referenceId: _fields[i].referenceId,
            onUrlChanged: (url) => _onUrlChanged(_fields[i], url),
          ),
          if (_verifying[_fields[i].getter] == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verifying ${_fields[i].label}…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else if (_verified[_fields[i].getter] == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${_fields[i].label} verified',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            )
          else if ((_errors[_fields[i].getter] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errors[_fields[i].getter]!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
              ),
            ),
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
                    '$uploaded of $total documents verified',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload the correct document for each slot. Wrong files are rejected, like Aadhaar checks.',
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
    required this.expectedType,
    required this.getter,
  });

  final String label;
  final CloudinaryFileCategory category;
  final String referenceId;
  final String expectedType;
  final _DocGetter getter;
}
