import 'package:open_space_parking/features/employee/domain/entities/construction_progress_entry.dart';
import 'package:open_space_parking/features/employee/domain/entities/employee_notification.dart';
import 'package:open_space_parking/features/employee/domain/entities/quotation.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';

abstract class EmployeeRepository {
  Future<List<LandOwnerRequest>> getAssignedProjects(String employeeId);

  Future<List<LandOwnerRequest>> getCompletedProjects(String employeeId);

  Future<LandOwnerRequest?> getTicketById({
    required String ticketId,
    required String employeeId,
  });

  Future<Quotation> submitQuotation({
    required String employeeId,
    required String requestId,
    required String ticketId,
    required double amount,
    required double materialsCost,
    required double laborCost,
    required int timelineDays,
    required String description,
  });

  Future<Quotation?> getQuotation(String ticketId);

  Future<void> updateNavigationNotes({
    required String requestId,
    required String employeeId,
    required String notes,
  });

  Future<ConstructionProgressEntry> updateConstructionProgress({
    required String employeeId,
    required String requestId,
    required String ticketId,
    required int progressPercent,
    required String notes,
  });

  Future<List<ConstructionProgressEntry>> getProgressHistory(String ticketId);

  Future<void> markProjectCompleted({
    required String requestId,
    required String employeeId,
  });

  Future<void> verifyDocuments({
    required String requestId,
    required String employeeId,
  });

  Future<List<EmployeeNotification>> getNotifications(String employeeId);

  Future<void> markNotificationRead(String notificationId);

  Future<int> getUnreadCount(String employeeId);

  Future<String?> getFullName(String employeeId);

  /// Mobile number assigned by admin when the employee was created.
  Future<String?> getPhone(String employeeId);
}
