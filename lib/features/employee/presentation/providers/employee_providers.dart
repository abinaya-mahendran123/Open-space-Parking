import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/features/employee/domain/entities/construction_progress_entry.dart';
import 'package:open_space_parking/features/employee/domain/entities/employee_notification.dart';
import 'package:open_space_parking/features/employee/domain/entities/quotation.dart';
import 'package:open_space_parking/features/employee/domain/repositories/employee_repository.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => sl<EmployeeRepository>(),
);

final employeeLoadingProvider = StateProvider<bool>((ref) => false);

final assignedProjectsProvider =
    FutureProvider.family<List<LandOwnerRequest>, String>((ref, employeeId) {
  return ref.read(employeeRepositoryProvider).getAssignedProjects(employeeId);
});

final completedProjectsProvider =
    FutureProvider.family<List<LandOwnerRequest>, String>((ref, employeeId) {
  return ref.read(employeeRepositoryProvider).getCompletedProjects(employeeId);
});

final employeeTicketProvider =
    FutureProvider.family<LandOwnerRequest?, ({String ticketId, String employeeId})>(
  (ref, args) {
    return ref.read(employeeRepositoryProvider).getTicketById(
          ticketId: args.ticketId,
          employeeId: args.employeeId,
        );
  },
);

final ticketQuotationProvider =
    FutureProvider.family<Quotation?, String>((ref, ticketId) {
  return ref.read(employeeRepositoryProvider).getQuotation(ticketId);
});

final progressHistoryProvider =
    FutureProvider.family<List<ConstructionProgressEntry>, String>((ref, ticketId) {
  return ref.read(employeeRepositoryProvider).getProgressHistory(ticketId);
});

final employeeNotificationsProvider =
    FutureProvider.family<List<EmployeeNotification>, String>((ref, employeeId) {
  return ref.read(employeeRepositoryProvider).getNotifications(employeeId);
});

final employeeUnreadCountProvider =
    FutureProvider.family<int, String>((ref, employeeId) async {
  return ref.read(notificationRepositoryProvider).getUnreadCount(
        recipientId: employeeId,
        recipientType: NotificationRecipientType.employee,
      );
});
