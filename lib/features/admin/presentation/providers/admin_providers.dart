import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/services/api/admin_operations_api_service.dart';
import 'package:open_space_parking/core/services/api/document_verification_service.dart';
import 'package:open_space_parking/features/admin/domain/entities/admin_operations_analytics.dart';
import 'package:open_space_parking/features/admin/domain/entities/admin_statistics.dart';
import 'package:open_space_parking/features/admin/domain/entities/document_verification_report.dart';
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
  // Watch filter fields individually so typing into searchQuery does not
  // refetch — only the debounced search string triggers a network call.
  final status = ref.watch(ticketFilterProvider.select((f) => f.status));
  final requestType =
      ref.watch(ticketFilterProvider.select((f) => f.requestType));
  final unassignedOnly =
      ref.watch(ticketFilterProvider.select((f) => f.unassignedOnly));
  final debounced = ref.watch(debouncedSearchProvider);
  return ref.read(adminRepositoryProvider).getAllTickets(
        searchQuery: debounced,
        statusFilter: status,
        typeFilter: requestType,
        unassignedOnly: unassignedOnly ? true : null,
      );
});

final adminTicketDetailProvider =
    FutureProvider.family<LandOwnerRequest?, String>((ref, ticketId) async {
  ref.keepAlive();
  return ref.read(adminRepositoryProvider).getTicketById(ticketId);
});

final documentVerificationServiceProvider = Provider<DocumentVerificationService>(
  (ref) => DocumentVerificationService(),
);

final documentVerificationProvider = FutureProvider.autoDispose
    .family<DocumentVerificationReport?, String>((ref, ticketId) async {
  final ticket = await ref.watch(adminTicketDetailProvider(ticketId).future);
  if (ticket == null) return null;
  return ref.read(documentVerificationServiceProvider).verifyTicket(
        ownerDetails: ticket.ownerDetails,
        documents: ticket.documents,
        landDetails: ticket.landDetails,
      );
});

final adminEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  ref.keepAlive();
  return ref.read(adminRepositoryProvider).getEmployees();
});

final adminEmployeeTicketsProvider =
    FutureProvider.autoDispose.family<List<LandOwnerRequest>, String>((ref, employeeId) {
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

enum AdminOpsRange { days7, days30, custom }

String formatOpsDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime opsDayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Inclusive day count for an ops date window (e.g. Mon–Sun = 7).
int opsInclusiveDayCount(DateTime from, DateTime to) {
  final a = opsDayOnly(from);
  final b = opsDayOnly(to);
  return b.difference(a).inDays.abs() + 1;
}

/// Max inclusive days allowed for a preset; `null` means no limit (custom).
int? maxInclusiveDaysForOpsRange(AdminOpsRange range) {
  switch (range) {
    case AdminOpsRange.days7:
      return 7;
    case AdminOpsRange.days30:
      return 30;
    case AdminOpsRange.custom:
      return null;
  }
}

class AdminOpsFilterState {
  const AdminOpsFilterState({
    this.listingId,
    this.range = AdminOpsRange.days7,
    required this.fromDate,
    required this.toDate,
  });

  factory AdminOpsFilterState.initial() {
    final to = opsDayOnly(DateTime.now());
    final from = to.subtract(const Duration(days: 6));
    return AdminOpsFilterState(fromDate: from, toDate: to);
  }

  final String? listingId;
  final AdminOpsRange range;
  final DateTime fromDate;
  final DateTime toDate;

  AdminOpsFilterState copyWith({
    String? listingId,
    AdminOpsRange? range,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearListing = false,
  }) {
    return AdminOpsFilterState(
      listingId: clearListing ? null : (listingId ?? this.listingId),
      range: range ?? this.range,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }
}

class AdminOpsFilterNotifier extends StateNotifier<AdminOpsFilterState> {
  AdminOpsFilterNotifier() : super(AdminOpsFilterState.initial());

  void setListing(String? listingId) {
    state = state.copyWith(
      listingId: listingId,
      clearListing: listingId == null || listingId.isEmpty,
    );
  }

  void setPresetRange(AdminOpsRange range) {
    if (range == AdminOpsRange.custom) {
      state = state.copyWith(range: AdminOpsRange.custom);
      return;
    }
    final to = opsDayOnly(DateTime.now());
    final days = range == AdminOpsRange.days30 ? 29 : 6;
    final from = to.subtract(Duration(days: days));
    state = state.copyWith(range: range, fromDate: from, toDate: to);
  }

  /// Updates the visible date window. Keeps the current preset (7 / 30 / custom)
  /// so users can customize which week or month they are viewing.
  /// Returns `false` if the range exceeds the preset's max day limit.
  bool setDateRange({DateTime? from, DateTime? to, AdminOpsRange? range}) {
    var nextFrom = from != null ? opsDayOnly(from) : state.fromDate;
    var nextTo = to != null ? opsDayOnly(to) : state.toDate;
    if (nextFrom.isAfter(nextTo)) {
      final swap = nextFrom;
      nextFrom = nextTo;
      nextTo = swap;
    }
    final nextRange = range ?? state.range;
    final maxDays = maxInclusiveDaysForOpsRange(nextRange);
    if (maxDays != null &&
        opsInclusiveDayCount(nextFrom, nextTo) > maxDays) {
      return false;
    }
    state = state.copyWith(
      range: nextRange,
      fromDate: nextFrom,
      toDate: nextTo,
    );
    return true;
  }

  void setCustomRange({DateTime? from, DateTime? to}) {
    setDateRange(from: from, to: to, range: AdminOpsRange.custom);
  }
}

final adminOpsFilterProvider =
    StateNotifierProvider<AdminOpsFilterNotifier, AdminOpsFilterState>(
  (ref) => AdminOpsFilterNotifier(),
);

final adminOperationsApiProvider = Provider<AdminOperationsApiService>(
  (ref) => AdminOperationsApiService(),
);

final adminOperationsProvider =
    FutureProvider<AdminOperationsAnalytics>((ref) async {
  ref.keepAlive();
  final filter = ref.watch(adminOpsFilterProvider);
  return ref.read(adminOperationsApiProvider).fetchOperations(
        listingId: filter.listingId,
        from: formatOpsDay(filter.fromDate),
        to: formatOpsDay(filter.toDate),
      );
});
