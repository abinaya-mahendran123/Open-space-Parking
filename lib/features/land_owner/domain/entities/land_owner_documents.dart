import 'package:equatable/equatable.dart';

/// How property documents were verified.
enum DocumentVerificationMethod { manual, digilocker }

class LandOwnerDocuments extends Equatable {
  const LandOwnerDocuments({
    this.governmentIdPath,
    this.propertyDocumentPath,
    this.pattaPath,
    this.propertyTaxPath,
    // DigiLocker fields
    this.digilockerVerified = false,
    this.digilockerOwnerName,
    this.digilockerSurveyNumber,
    this.digilockerLandArea,
    this.digilockerDistrict,
    this.digilockerDocumentType,
    this.digilockerVerificationUrl,
    this.digilockerIssuedBy,
    this.digilockerIssuedOn,
    this.verificationMethod,
  });

  static const _unset = Object();

  /// Cloudinary secure URLs stored in MongoDB (not local file paths).
  final String? governmentIdPath;
  final String? propertyDocumentPath;
  final String? pattaPath;
  final String? propertyTaxPath;

  /// DigiLocker verification data (populated when land owner verifies via DigiLocker).
  final bool digilockerVerified;
  final String? digilockerOwnerName;
  final String? digilockerSurveyNumber;
  final String? digilockerLandArea;
  final String? digilockerDistrict;
  final String? digilockerDocumentType;
  final String? digilockerVerificationUrl;
  final String? digilockerIssuedBy;
  final String? digilockerIssuedOn;
  final DocumentVerificationMethod? verificationMethod;

  /// Documents are complete if either DigiLocker verified OR all manual docs uploaded.
  bool get isComplete =>
      digilockerVerified ||
      (propertyDocumentPath != null &&
          pattaPath != null &&
          propertyTaxPath != null);

  Map<String, dynamic> toJson() => {
        'governmentIdPath': governmentIdPath,
        'propertyDocumentPath': propertyDocumentPath,
        'pattaPath': pattaPath,
        'propertyTaxPath': propertyTaxPath,
        'digilockerVerified': digilockerVerified,
        'digilockerOwnerName': digilockerOwnerName,
        'digilockerSurveyNumber': digilockerSurveyNumber,
        'digilockerLandArea': digilockerLandArea,
        'digilockerDistrict': digilockerDistrict,
        'digilockerDocumentType': digilockerDocumentType,
        'digilockerVerificationUrl': digilockerVerificationUrl,
        'digilockerIssuedBy': digilockerIssuedBy,
        'digilockerIssuedOn': digilockerIssuedOn,
        'verificationMethod': verificationMethod?.name,
      };

  factory LandOwnerDocuments.fromJson(Map<String, dynamic> json) {
    DocumentVerificationMethod? method;
    final methodStr = json['verificationMethod'] as String?;
    if (methodStr == 'digilocker') {
      method = DocumentVerificationMethod.digilocker;
    } else if (methodStr == 'manual') {
      method = DocumentVerificationMethod.manual;
    }
    return LandOwnerDocuments(
      governmentIdPath: json['governmentIdPath'] as String?,
      propertyDocumentPath: json['propertyDocumentPath'] as String?,
      pattaPath: json['pattaPath'] as String?,
      propertyTaxPath: json['propertyTaxPath'] as String?,
      digilockerVerified: json['digilockerVerified'] as bool? ?? false,
      digilockerOwnerName: json['digilockerOwnerName'] as String?,
      digilockerSurveyNumber: json['digilockerSurveyNumber'] as String?,
      digilockerLandArea: json['digilockerLandArea'] as String?,
      digilockerDistrict: json['digilockerDistrict'] as String?,
      digilockerDocumentType: json['digilockerDocumentType'] as String?,
      digilockerVerificationUrl: json['digilockerVerificationUrl'] as String?,
      digilockerIssuedBy: json['digilockerIssuedBy'] as String?,
      digilockerIssuedOn: json['digilockerIssuedOn'] as String?,
      verificationMethod: method,
    );
  }

  LandOwnerDocuments copyWith({
    Object? governmentIdPath = _unset,
    Object? propertyDocumentPath = _unset,
    Object? pattaPath = _unset,
    Object? propertyTaxPath = _unset,
    bool? digilockerVerified,
    Object? digilockerOwnerName = _unset,
    Object? digilockerSurveyNumber = _unset,
    Object? digilockerLandArea = _unset,
    Object? digilockerDistrict = _unset,
    Object? digilockerDocumentType = _unset,
    Object? digilockerVerificationUrl = _unset,
    Object? digilockerIssuedBy = _unset,
    Object? digilockerIssuedOn = _unset,
    Object? verificationMethod = _unset,
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
      digilockerVerified: digilockerVerified ?? this.digilockerVerified,
      digilockerOwnerName: identical(digilockerOwnerName, _unset)
          ? this.digilockerOwnerName
          : digilockerOwnerName as String?,
      digilockerSurveyNumber: identical(digilockerSurveyNumber, _unset)
          ? this.digilockerSurveyNumber
          : digilockerSurveyNumber as String?,
      digilockerLandArea: identical(digilockerLandArea, _unset)
          ? this.digilockerLandArea
          : digilockerLandArea as String?,
      digilockerDistrict: identical(digilockerDistrict, _unset)
          ? this.digilockerDistrict
          : digilockerDistrict as String?,
      digilockerDocumentType: identical(digilockerDocumentType, _unset)
          ? this.digilockerDocumentType
          : digilockerDocumentType as String?,
      digilockerVerificationUrl: identical(digilockerVerificationUrl, _unset)
          ? this.digilockerVerificationUrl
          : digilockerVerificationUrl as String?,
      digilockerIssuedBy: identical(digilockerIssuedBy, _unset)
          ? this.digilockerIssuedBy
          : digilockerIssuedBy as String?,
      digilockerIssuedOn: identical(digilockerIssuedOn, _unset)
          ? this.digilockerIssuedOn
          : digilockerIssuedOn as String?,
      verificationMethod: identical(verificationMethod, _unset)
          ? this.verificationMethod
          : verificationMethod as DocumentVerificationMethod?,
    );
  }

  @override
  List<Object?> get props => [
        governmentIdPath,
        propertyDocumentPath,
        pattaPath,
        propertyTaxPath,
        digilockerVerified,
        digilockerOwnerName,
        digilockerSurveyNumber,
        digilockerLandArea,
        digilockerDistrict,
        digilockerDocumentType,
        digilockerVerificationUrl,
        digilockerIssuedBy,
        digilockerIssuedOn,
        verificationMethod,
      ];
}
