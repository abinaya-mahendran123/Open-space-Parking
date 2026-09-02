import 'dart:math';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';

/// Data returned after a successful DigiLocker property document verification.
class DigiLockerDocumentResult {
  const DigiLockerDocumentResult({
    required this.ownerName,
    required this.surveyNumber,
    required this.landArea,
    required this.district,
    required this.documentType,
    required this.verificationUrl,
    required this.issuedBy,
    required this.issuedOn,
    required this.isMock,
    this.village,
    this.taluk,
  });

  final String ownerName;
  final String surveyNumber;
  final String landArea;
  final String district;
  final String documentType;
  final String verificationUrl;
  final String issuedBy;
  final String issuedOn;
  final bool isMock;
  final String? village;
  final String? taluk;

  factory DigiLockerDocumentResult.fromJson(Map<String, dynamic> json) {
    return DigiLockerDocumentResult(
      ownerName: (json['ownerName'] as String? ?? '').trim(),
      surveyNumber: (json['surveyNumber'] as String? ?? '').trim(),
      landArea: (json['landArea'] as String? ?? '').trim(),
      district: (json['district'] as String? ?? '').trim(),
      documentType: (json['documentType'] as String? ?? 'Property Document').trim(),
      verificationUrl: (json['verificationUrl'] as String? ?? '').trim(),
      issuedBy: (json['issuedBy'] as String? ?? '').trim(),
      issuedOn: (json['issuedOn'] as String? ?? '').trim(),
      isMock: json['isMock'] as bool? ?? false,
      village: (json['village'] as String?)?.trim(),
      taluk: (json['taluk'] as String?)?.trim(),
    );
  }
}

/// An available document from DigiLocker that the user can select.
class DigiLockerFile {
  const DigiLockerFile({
    required this.uri,
    required this.name,
    required this.type,
    required this.issuer,
    this.date,
  });

  final String uri;
  final String name;
  final String type;
  final String issuer;
  final String? date;

  factory DigiLockerFile.fromJson(Map<String, dynamic> json) {
    return DigiLockerFile(
      uri: json['uri'] as String? ?? '',
      name: json['name'] as String? ?? json['type'] as String? ?? 'Document',
      type: json['type'] as String? ?? '',
      issuer: json['issuer'] as String? ?? '',
      date: json['date'] as String?,
    );
  }
}

/// Authorization session metadata for opening DigiLocker in a WebView.
class DigiLockerAuthLaunch {
  const DigiLockerAuthLaunch({
    required this.url,
    required this.state,
    required this.isSandbox,
    this.redirectUri,
  });

  final String url;
  final String state;
  final bool isSandbox;
  final String? redirectUri;
}

/// Handles the DigiLocker OAuth flow and document fetching.
class DigiLockerService {
  DigiLockerService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Step 1: Get the DigiLocker URL to open (portal or OAuth authorize page).
  Future<DigiLockerAuthLaunch> getAuthLaunch() async {
    final state = _randomState();
    try {
      final result = await _apiClient
          .get('/api/digilocker/auth-url?state=$state')
          .timeout(const Duration(seconds: 10));

      final url = result['url'] as String? ?? '';
      if (url.isEmpty) {
        throw const AppException('Could not get DigiLocker URL.');
      }

      return DigiLockerAuthLaunch(
        url: url,
        state: result['state'] as String? ?? state,
        isSandbox: result['isSandbox'] as bool? ?? false,
        redirectUri: result['redirectUri'] as String?,
      );
    } on AppException {
      rethrow;
    }
  }

  /// Step 2: Exchange the authorization code for a token and get file list.
  Future<({String accessToken, List<DigiLockerFile> files, bool isMock})>
      exchangeCode(String code, {bool isMock = false}) async {
    try {
      final result = await _apiClient
          .post('/api/digilocker/exchange', {
            'code': code,
            'isMock': isMock,
          })
          .timeout(const Duration(seconds: 20));

      final accessToken = result['access_token'] as String? ?? '';
      final rawFiles = result['files'] as List<dynamic>? ?? [];
      final files = rawFiles
          .whereType<Map<String, dynamic>>()
          .map(DigiLockerFile.fromJson)
          .toList();

      return (
        accessToken: accessToken,
        files: files,
        isMock: result['isMock'] as bool? ?? false,
      );
    } on AppException {
      rethrow;
    }
  }

  /// Step 3: Fetch the full details of a selected document.
  Future<DigiLockerDocumentResult> fetchDocument(
    String accessToken,
    String uri, {
    bool isMock = false,
  }) async {
    try {
      final result = await _apiClient
          .post('/api/digilocker/fetch-document', {
            'accessToken': accessToken,
            'uri': uri,
            'isMock': isMock,
          })
          .timeout(const Duration(seconds: 20));

      final doc = result['document'] as Map<String, dynamic>?;
      if (doc == null) {
        throw const AppException('No document data returned from DigiLocker.');
      }
      return DigiLockerDocumentResult.fromJson(doc);
    } on AppException {
      rethrow;
    }
  }

  String _randomState() =>
      Random.secure().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
}
