import 'package:flutter/material.dart';



import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';

import 'package:open_space_parking/core/cloudinary/presentation/widgets/cloudinary_upload_tile.dart';

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



  static const _fields = [

    _DocField(

      label: 'Government ID',

      category: CloudinaryFileCategory.document,

      referenceId: 'government_id',

      getter: _DocGetter.governmentId,

    ),

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

  ];



  @override

  void initState() {

    super.initState();

    _documents = widget.initial;

  }



  void _update(LandOwnerDocuments docs) {

    setState(() => _documents = docs);

    widget.onChanged(docs);

  }



  bool get isComplete => _documents.isComplete;



  int get _uploadedCount {

    var count = 0;

    if (_documents.governmentIdPath != null) count++;

    if (_documents.propertyDocumentPath != null) count++;

    if (_documents.pattaPath != null) count++;

    if (_documents.propertyTaxPath != null) count++;

    return count;

  }



  String? _urlFor(_DocGetter getter) {

    return switch (getter) {

      _DocGetter.governmentId => _documents.governmentIdPath,

      _DocGetter.propertyDocument => _documents.propertyDocumentPath,

      _DocGetter.patta => _documents.pattaPath,

      _DocGetter.propertyTax => _documents.propertyTaxPath,

    };

  }



  void _onUrlChanged(_DocGetter getter, String? url) {

    final updated = switch (getter) {

      _DocGetter.governmentId =>

        _documents.copyWith(governmentIdPath: url),

      _DocGetter.propertyDocument =>

        _documents.copyWith(propertyDocumentPath: url),

      _DocGetter.patta => _documents.copyWith(pattaPath: url),

      _DocGetter.propertyTax =>

        _documents.copyWith(propertyTaxPath: url),

    };

    _update(updated);

  }



  @override

  Widget build(BuildContext context) {

    final colorScheme = Theme.of(context).colorScheme;

    final total = _fields.length;

    final uploaded = _uploadedCount;

    final progress = uploaded / total;



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Card(

          child: Padding(

            padding: const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  children: [

                    Icon(

                      uploaded == total

                          ? Icons.check_circle

                          : Icons.info_outline,

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

                  'Upload each document below. You\'ll see the file name and a green check when it\'s ready.',

                  style: Theme.of(context).textTheme.bodySmall?.copyWith(

                        color: colorScheme.onSurfaceVariant,

                      ),

                ),

              ],

            ),

          ),

        ),

        const SizedBox(height: 16),

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

    );

  }

}



enum _DocGetter {

  governmentId,

  propertyDocument,

  patta,

  propertyTax,

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


