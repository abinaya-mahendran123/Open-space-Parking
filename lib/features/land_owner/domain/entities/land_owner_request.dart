import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_type.dart';

class LandOwnerRequest extends Equatable {
  const LandOwnerRequest({
    required this.id,
    required this.ticketId,
    required this.ownerId,
    required this.requestType,
    required this.status,
    required this.ownerDetails,
    required this.documents,
    required this.landDetails,
    required this.submittedAt,
    this.parkingPreferences,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.documentsVerified = false,
    this.adminNotes,
    this.reviewedAt,
    this.reviewedBy,
    this.constructionProgress = 0,
    this.navigationNotes,
    this.completedAt,
  });

  final String id;
  final String ticketId;
  final String ownerId;
  final LandOwnerRequestType requestType;
  final RequestStatus status;
  final OwnerDetails ownerDetails;
  final LandOwnerDocuments documents;
  final LandDetails landDetails;
  final ParkingPreferences? parkingPreferences;
  final DateTime submittedAt;
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final bool documentsVerified;
  final String? adminNotes;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final int constructionProgress;
  final String? navigationNotes;
  final DateTime? completedAt;

  LandOwnerRequest copyWith({
    RequestStatus? status,
    String? assignedEmployeeId,
    String? assignedEmployeeName,
    bool? documentsVerified,
    String? adminNotes,
    DateTime? reviewedAt,
    String? reviewedBy,
    int? constructionProgress,
    String? navigationNotes,
    DateTime? completedAt,
  }) {
    return LandOwnerRequest(
      id: id,
      ticketId: ticketId,
      ownerId: ownerId,
      requestType: requestType,
      status: status ?? this.status,
      ownerDetails: ownerDetails,
      documents: documents,
      landDetails: landDetails,
      parkingPreferences: parkingPreferences,
      submittedAt: submittedAt,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      documentsVerified: documentsVerified ?? this.documentsVerified,
      adminNotes: adminNotes ?? this.adminNotes,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      constructionProgress: constructionProgress ?? this.constructionProgress,
      navigationNotes: navigationNotes ?? this.navigationNotes,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ticketId,
        ownerId,
        requestType,
        status,
        ownerDetails,
        documents,
        landDetails,
        parkingPreferences,
        submittedAt,
        assignedEmployeeId,
        assignedEmployeeName,
        documentsVerified,
        adminNotes,
        reviewedAt,
        reviewedBy,
        constructionProgress,
        navigationNotes,
        completedAt,
      ];
}
