import 'package:equatable/equatable.dart';

class AdminStatistics extends Equatable {
  const AdminStatistics({
    required this.totalTickets,
    required this.submittedCount,
    required this.underReviewCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.buildParkingCount,
    required this.existingParkingCount,
    required this.activeEmployees,
    required this.unassignedTickets,
    required this.documentsPendingVerification,
  });

  final int totalTickets;
  final int submittedCount;
  final int underReviewCount;
  final int approvedCount;
  final int rejectedCount;
  final int inProgressCount;
  final int completedCount;
  final int buildParkingCount;
  final int existingParkingCount;
  final int activeEmployees;
  final int unassignedTickets;
  final int documentsPendingVerification;

  @override
  List<Object?> get props => [
        totalTickets,
        submittedCount,
        underReviewCount,
        approvedCount,
        rejectedCount,
        inProgressCount,
        completedCount,
        buildParkingCount,
        existingParkingCount,
        activeEmployees,
        unassignedTickets,
        documentsPendingVerification,
      ];
}
