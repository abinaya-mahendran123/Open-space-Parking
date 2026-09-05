import 'package:equatable/equatable.dart';

class DocumentVerificationItem extends Equatable {
  const DocumentVerificationItem({
    required this.id,
    required this.label,
    required this.present,
    required this.pass,
    required this.matchPercent,
    required this.status,
    this.detectedType,
    this.message,
    this.error,
  });

  final String id;
  final String label;
  final bool present;
  final bool pass;
  final int matchPercent;
  final String status;
  final String? detectedType;
  final String? message;
  final String? error;

  factory DocumentVerificationItem.fromJson(Map<String, dynamic> json) {
    return DocumentVerificationItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      present: json['present'] as bool? ?? false,
      pass: json['pass'] as bool? ?? false,
      matchPercent: (json['matchPercent'] as num?)?.round() ?? 0,
      status: json['status'] as String? ?? 'failed',
      detectedType: json['detectedType'] as String?,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        label,
        present,
        pass,
        matchPercent,
        status,
        detectedType,
        message,
        error,
      ];
}

class DocumentVerificationCheck extends Equatable {
  const DocumentVerificationCheck({
    required this.id,
    required this.label,
    required this.pass,
    this.severity = 'normal',
    this.expected,
    this.found,
    this.score,
    this.note,
  });

  final String id;
  final String label;
  final bool pass;
  final String severity;
  final String? expected;
  final String? found;
  final double? score;
  final String? note;

  factory DocumentVerificationCheck.fromJson(Map<String, dynamic> json) {
    return DocumentVerificationCheck(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      pass: json['pass'] as bool? ?? false,
      severity: json['severity'] as String? ?? 'normal',
      expected: json['expected'] as String?,
      found: json['found'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, label, pass, severity, expected, found, score, note];
}

class DocumentVerificationReport extends Equatable {
  const DocumentVerificationReport({
    required this.status,
    required this.overallScore,
    required this.passCount,
    required this.totalChecks,
    required this.readyForQuickApproval,
    required this.checks,
    this.documents = const [],
    this.extractedOwnerName,
    this.extractedSurveyNumber,
    this.extractedDistrict,
  });

  final String status;
  final double overallScore;
  final int passCount;
  final int totalChecks;
  final bool readyForQuickApproval;
  final List<DocumentVerificationCheck> checks;
  final List<DocumentVerificationItem> documents;
  final String? extractedOwnerName;
  final String? extractedSurveyNumber;
  final String? extractedDistrict;

  factory DocumentVerificationReport.fromJson(Map<String, dynamic> json) {
    final extracted = json['extracted'] as Map<String, dynamic>? ?? {};
    final rawChecks = json['checks'] as List<dynamic>? ?? [];
    final rawDocs = json['documents'] as List<dynamic>? ?? [];
    return DocumentVerificationReport(
      status: json['status'] as String? ?? 'complete',
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
      passCount: json['passCount'] as int? ?? 0,
      totalChecks: json['totalChecks'] as int? ?? 0,
      readyForQuickApproval: json['readyForQuickApproval'] as bool? ?? false,
      checks: rawChecks
          .whereType<Map<String, dynamic>>()
          .map(DocumentVerificationCheck.fromJson)
          .toList(),
      documents: rawDocs
          .whereType<Map<String, dynamic>>()
          .map(DocumentVerificationItem.fromJson)
          .toList(),
      extractedOwnerName: extracted['ownerName'] as String?,
      extractedSurveyNumber: extracted['surveyNumber'] as String?,
      extractedDistrict: extracted['district'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        status,
        overallScore,
        passCount,
        totalChecks,
        readyForQuickApproval,
        checks,
        documents,
        extractedOwnerName,
        extractedSurveyNumber,
        extractedDistrict,
      ];
}
