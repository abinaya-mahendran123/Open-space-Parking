import 'package:open_space_parking/features/admin/domain/entities/admin_statistics.dart';
import 'package:open_space_parking/features/admin/domain/entities/created_employee_result.dart';
import 'package:open_space_parking/features/admin/domain/entities/employee.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_type.dart';

abstract class AdminRepository {
  Future<List<LandOwnerRequest>> getAllTickets({
    String? searchQuery,
    RequestStatus? statusFilter,
    LandOwnerRequestType? typeFilter,
    bool? unassignedOnly,
  });

  Future<LandOwnerRequest?> getTicketById(String ticketId);

  Future<void> verifyDocuments({
    required String requestId,
    required bool verified,
    required String adminId,
  });

  Future<void> approveTicket({
    required String requestId,
    required String adminId,
    String? notes,
  });

  Future<void> rejectTicket({
    required String requestId,
    required String adminId,
    required String reason,
  });

  Future<String> assignEmployee({
    required String requestId,
    required String employeeId,
    required String employeeName,
    required String adminId,
  });

  Future<List<Employee>> getEmployees({bool activeOnly = false});

  Future<List<LandOwnerRequest>> getEmployeeAssignedTickets(String employeeId);

  Future<CreatedEmployeeResult> createEmployee({
    required String fullName,
    required String phone,
  });

  Future<void> updateEmployee(Employee employee);

  Future<void> setEmployeeActive({
    required String employeeId,
    required bool isActive,
  });

  Future<AdminStatistics> getStatistics();
}
