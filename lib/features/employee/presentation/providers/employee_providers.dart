import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/domain/entities/construction_progress_entry.dart';
import 'package:open_space_parking/features/employee/domain/entities/employee_notification.dart';
import 'package:open_space_parking/features/employee/domain/entities/quotation.dart';
import 'package:open_space_parking/features/employee/domain/repositories/employee_repository.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => sl<EmployeeRepository>(),
);

final employeeLoadingProvider = StateProvider<bool>((ref) => false);

/// Active tab inside the employee shell. Updated locally — no route navigation.
final employeeShellTabProvider = StateProvider<int>((ref) => 0);

class EmployeeDashboardStats {
  const EmployeeDashboardStats({
    required this.assigned,
    required this.completedCount,
    required this.unreadCount,
  });

  final List<LandOwnerRequest> assigned;
  final int completedCount;
  final int unreadCount;

  static const empty = EmployeeDashboardStats(
    assigned: [],
    completedCount: 0,
    unreadCount: 0,
  );
}

final employeeDashboardStatsProvider =
    FutureProvider.family<EmployeeDashboardStats, String>((ref, employeeId) async {
  ref.keepAlive();
  if (employeeId.isEmpty) return EmployeeDashboardStats.empty;

  final repo = ref.read(employeeRepositoryProvider);
  final results = await Future.wait([
    repo.getAssignedProjects(employeeId),
    repo.getCompletedProjects(employeeId),
    repo.getUnreadCount(employeeId),
  ]);

  return EmployeeDashboardStats(
    assigned: results[0] as List<LandOwnerRequest>,
    completedCount: (results[1] as List<LandOwnerRequest>).length,
    unreadCount: results[2] as int,
  );
});

final assignedProjectsProvider =
    FutureProvider.family<List<LandOwnerRequest>, String>((ref, employeeId) {
  ref.keepAlive();
  return ref.read(employeeRepositoryProvider).getAssignedProjects(employeeId);
});

final completedProjectsProvider =
    FutureProvider.family<List<LandOwnerRequest>, String>((ref, employeeId) {
  ref.keepAlive();
  return ref.read(employeeRepositoryProvider).getCompletedProjects(employeeId);
});

final employeeTicketProvider =
    FutureProvider.family<LandOwnerRequest?, ({String ticketId, String employeeId})>(
  (ref, args) {
    ref.keepAlive();
    return ref.read(employeeRepositoryProvider).getTicketById(
          ticketId: args.ticketId,
          employeeId: args.employeeId,
        );
  },
);

final ticketQuotationProvider =
    FutureProvider.family<Quotation?, String>((ref, ticketId) {
  ref.keepAlive();
  return ref.read(employeeRepositoryProvider).getQuotation(ticketId);
});

final progressHistoryProvider =
    FutureProvider.family<List<ConstructionProgressEntry>, String>((ref, ticketId) {
  ref.keepAlive();
  return ref.read(employeeRepositoryProvider).getProgressHistory(ticketId);
});

final employeeNotificationsProvider =
    FutureProvider.family<List<EmployeeNotification>, String>((ref, employeeId) {
  ref.keepAlive();
  return ref.read(employeeRepositoryProvider).getNotifications(employeeId);
});

final employeeWelcomeNameProvider = FutureProvider<String>((ref) async {
  ref.keepAlive();
  final session = ref.read(authStateProvider).session;
  if (session == null || session.role != UserRole.employee) {
    return 'Employee';
  }

  final fromSession = session.displayName.trim();
  if (fromSession.isNotEmpty && !_looksLikePhoneOrLoginId(fromSession)) {
    return fromSession;
  }

  final employeeId = session.userId;
  if (employeeId.isEmpty) return 'Employee';

  final fullName =
      await ref.read(employeeRepositoryProvider).getFullName(employeeId);
  if (fullName != null && fullName.isNotEmpty) {
    return fullName;
  }

  return 'Employee';
});

bool _looksLikePhoneOrLoginId(String value) {
  final trimmed = value.trim();
  if (trimmed.contains('@')) return true;
  if (trimmed.startsWith('emp.')) return true;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 && RegExp(r'^\+?\d[\d\s-]+$').hasMatch(trimmed);
}

final employeeUnreadCountProvider =
    FutureProvider.family<int, String>((ref, employeeId) async {
  ref.keepAlive();
  if (employeeId.isEmpty) return 0;
  return ref.read(employeeRepositoryProvider).getUnreadCount(employeeId);
});

/// Admin-assigned mobile for the signed-in employee (session, then DB).
final employeeAssignedPhoneProvider = FutureProvider<String>((ref) async {
  ref.keepAlive();
  final session = ref.watch(authStateProvider).session;
  if (session == null || session.role != UserRole.employee) return '';

  final fromSession = session.phone.trim();
  if (fromSession.isNotEmpty) return fromSession;

  final employeeId = session.userId;
  if (employeeId.isEmpty) return '';
  return await ref.read(employeeRepositoryProvider).getPhone(employeeId) ?? '';
});
