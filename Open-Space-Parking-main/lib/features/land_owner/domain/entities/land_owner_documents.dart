import 'package:equatable/equatable.dart';

class LandOwnerDocuments extends Equatable {
  const LandOwnerDocuments({
    this.governmentIdPath,
    this.propertyDocumentPath,
    this.pattaPath,
    this.propertyTaxPath,
  });

  static const _unset = Object();

  /// Cloudinary secure URLs stored in MongoDB (not local file paths).
  final String? governmentIdPath;
  final String? propertyDocumentPath;
  final String? pattaPath;
  final String? propertyTaxPath;

  bool get isComplete =>
      governmentIdPath != null &&
      propertyDocumentPath != null &&
      pattaPath != null &&
      propertyTaxPath != null;

  Map<String, dynamic> toJson() => {
        'governmentIdPath': governmentIdPath,
        'propertyDocumentPath': propertyDocumentPath,
        'pattaPath': pattaPath,
        'propertyTaxPath': propertyTaxPath,
      };

  factory LandOwnerDocuments.fromJson(Map<String, dynamic> json) {
    return LandOwnerDocuments(
      governmentIdPath: json['governmentIdPath'] as String?,
      propertyDocumentPath: json['propertyDocumentPath'] as String?,
      pattaPath: json['pattaPath'] as String?,
      propertyTaxPath: json['propertyTaxPath'] as String?,
    );
  }

  LandOwnerDocuments copyWith({
    Object? governmentIdPath = _unset,
    Object? propertyDocumentPath = _unset,
    Object? pattaPath = _unset,
    Object? propertyTaxPath = _unset,
  }) {
    return LandOwnerDocuments(
      governmentIdPath: identical(governmentIdPath, _unset)
          ? this.governmentIdPath
          : governmentIdPath as String?,
      propertyDocumentPath: identical(propertyDocumentPath, _unset)
          ? this.propertyDocumentPath
          : propertyDocumentPath as String?,
      pattaPath:
          identical(pattaPath, _unset) ? this.pattaPath : pattaPath as String?,
      propertyTaxPath: identical(propertyTaxPath, _unset)
          ? this.propertyTaxPath
          : propertyTaxPath as String?,
    );
  }

  @override
  List<Object?> get props => [
        governmentIdPath,
        propertyDocumentPath,
        pattaPath,
        propertyTaxPath,
      ];
}
