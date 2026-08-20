import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/features/admin/domain/entities/admin_statistics.dart';
import 'package:open_space_parking/features/admin/domain/entities/employee.dart';
import 'package:open_space_parking/features/admin/domain/repositories/admin_repository.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_type.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => sl<AdminRepository>(),
);

final adminLoadingProvider = StateProvider<bool>((ref) => false);

class TicketFilterState {
  const TicketFilterState({
    this.searchQuery = '',
    this.status,
    this.requestType,
    this.unassignedOnly = false,
  });

  final String searchQuery;
  final RequestStatus? status;
  final LandOwnerRequestType? requestType;
  final bool unassignedOnly;

  TicketFilterState copyWith({
    String? searchQuery,
    RequestStatus? status,
    LandOwnerRequestType? requestType,
    bool? unassignedOnly,
    bool clearStatus = false,
    bool clearType = false,
  }) {
    return TicketFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      status: clearStatus ? null : (status ?? this.status),
      requestType: clearType ? null : (requestType ?? this.requestType),
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
    );
  }
}

class TicketFilterNotifier extends StateNotifier<TicketFilterState> {
  TicketFilterNotifier() : super(const TicketFilterState());

  void setSearch(String query) => state = state.copyWith(searchQuery: query);

  void setStatus(RequestStatus? status) {
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
  }

  void setType(LandOwnerRequestType? type) {
    state = type == null
        ? state.copyWith(clearType: true)
        : state.copyWith(requestType: type);
  }

  void setUnassignedOnly(bool value) {
    state = state.copyWith(unassignedOnly: value);
  }

  void reset() => state = const TicketFilterState();
}

final ticketFilterProvider =
    StateNotifierProvider<TicketFilterNotifier, TicketFilterState>(
  (ref) => TicketFilterNotifier(),
);

/// Debounced search query — the UI updates this 400ms after the user stops typing.
/// Kept as a top-level (non-private) provider so `admin_tickets_page.dart` can
/// write to it directly.
final debouncedSearchProvider = StateProvider<String>((ref) => '');

final adminTicketsProvider = FutureProvider<List<LandOwnerRequest>>((ref) async {
  ref.keepAlive();
  final filter = ref.watch(ticketFilterProvider);
  // Use debounced search to avoid a network call on every keystroke.
  final debounced = ref.watch(debouncedSearchProvider);
  return ref.read(adminRepositoryProvider).getAllTickets(
        searchQuery: debounced,
        statusFilter: filter.status,
        typeFilter: filter.requestType,
        unassignedOnly: filter.unassignedOnly ? true : null,
      );
});

final adminTicketDetailProvider =
    FutureProvider.family<LandOwnerRequest?, String>((ref, ticketId) async {
  return ref.read(adminRepositoryProvider).getTicketById(ticketId);
});

final adminEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  ref.keepAlive();
  return ref.read(adminRepositoryProvider).getEmployees();
});

final adminEmployeeTicketsProvider =
    FutureProvider.family<List<LandOwnerRequest>, String>((ref, employeeId) {
  return ref
      .read(adminRepositoryProvider)
      .getEmployeeAssignedTickets(employeeId);
});

final activeEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  ref.keepAlive();
  return ref.read(adminRepositoryProvider).getEmployees(activeOnly: true);
});

final adminStatisticsProvider = FutureProvider<AdminStatistics>((ref) async {
  ref.keepAlive();
  return ref.read(adminRepositoryProvider).getStatistics();
});
