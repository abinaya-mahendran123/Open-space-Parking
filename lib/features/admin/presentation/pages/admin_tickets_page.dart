import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_type.dart';

class AdminTicketsPage extends ConsumerStatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  ConsumerState<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends ConsumerState<AdminTicketsPage> {
  static final _dateFormat = DateFormat('dd MMM yyyy');

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(ticketFilterProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.submitted:
        return Colors.blue;
      case RequestStatus.underReview:
        return Colors.orange;
      case RequestStatus.approved:
        return Colors.green;
      case RequestStatus.rejected:
        return Colors.red;
      case RequestStatus.inProgress:
        return Colors.indigo;
      case RequestStatus.completed:
        return Colors.teal;
    }
  }

  String _statusDropdownValue(TicketFilterState filter) {
    if (filter.docsPendingOnly) return 'docs_pending';
    return filter.status?.value ?? 'all';
  }

  String _typeDropdownValue(TicketFilterState filter) {
    if (filter.assignmentFilter == TicketAssignmentFilter.unassigned) {
      return 'unassigned';
    }
    if (filter.assignmentFilter == TicketAssignmentFilter.assigned) {
      return 'assigned';
    }
    final type = filter.requestType;
    if (type != null) return 'type:${type.value}';
    return 'all';
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(ticketFilterProvider);
    final ticketsAsync = ref.watch(adminTicketsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search ticket, owner, phone, employee...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: filter.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(ticketFilterProvider.notifier)
                                .setSearch('');
                            ref
                                .read(debouncedSearchProvider.notifier)
                                .state = '';
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  ref.read(ticketFilterProvider.notifier).setSearch(v);
                  final debounced =
                      ref.read(debouncedSearchProvider.notifier);
                  final query = v;
                  Future<void>.delayed(
                    const Duration(milliseconds: 400),
                    () {
                      if (ref.read(ticketFilterProvider).searchQuery ==
                          query) {
                        debounced.state = query;
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _statusDropdownValue(filter),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Status'),
                        ),
                        ...RequestStatus.values.map(
                          (status) => DropdownMenuItem(
                            value: status.value,
                            child: Text(status.label),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'docs_pending',
                          child: Text('Docs Pending'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        final notifier =
                            ref.read(ticketFilterProvider.notifier);
                        if (value == 'all') {
                          notifier.setStatus(null);
                          notifier.setDocsPendingOnly(false);
                        } else if (value == 'docs_pending') {
                          notifier.setStatus(null);
                          notifier.setDocsPendingOnly(true);
                        } else {
                          notifier.setDocsPendingOnly(false);
                          notifier.setStatus(
                            RequestStatus.values.firstWhere(
                              (s) => s.value == value,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _typeDropdownValue(filter),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Type / assignment',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Types'),
                        ),
                        ...LandOwnerRequestType.values.map(
                          (type) => DropdownMenuItem(
                            value: 'type:${type.value}',
                            child: Text(type.label),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'unassigned',
                          child: Text('Unassigned'),
                        ),
                        const DropdownMenuItem(
                          value: 'assigned',
                          child: Text('Assigned'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        final notifier =
                            ref.read(ticketFilterProvider.notifier);
                        if (value == 'all') {
                          notifier.setType(null);
                          notifier.setAssignmentFilter(
                            TicketAssignmentFilter.all,
                          );
                        } else if (value == 'unassigned') {
                          notifier.setType(null);
                          notifier.setUnassignedOnly(true);
                        } else if (value == 'assigned') {
                          notifier.setType(null);
                          notifier.setAssignedOnly(true);
                        } else if (value.startsWith('type:')) {
                          final typeValue = value.substring(5);
                          notifier.setAssignmentFilter(
                            TicketAssignmentFilter.all,
                          );
                          notifier.setType(
                            LandOwnerRequestType.values.firstWhere(
                              (t) => t.value == typeValue,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            loading: () => const AppLoadingWidget(message: 'Loading tickets...'),
            error: (_, __) => AppErrorWidget(
              message: 'Failed to load construction requests',
              onRetry: () => ref.invalidate(adminTicketsProvider),
            ),
            data: (tickets) {
              if (tickets.isEmpty) {
                return const Center(
                    child: Text('No tickets match your filters.'));
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminTicketsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return _TicketCard(
                      ticket: ticket,
                      dateLabel:
                          _dateFormat.format(ticket.submittedAt.toLocal()),
                      statusColor: _statusColor(ticket.status),
                      onTap: () => context.push(
                        RoutePaths.adminTicketDetail(ticket.ticketId),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.dateLabel,
    required this.statusColor,
    required this.onTap,
  });

  final LandOwnerRequest ticket;
  final String dateLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.ticketId,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(ticket.status.label),
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(ticket.requestType.label),
              Text(
                  '${ticket.ownerDetails.fullName} • ${ticket.ownerDetails.phone}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (ticket.documentsVerified)
                    const Chip(
                      avatar: Icon(Icons.verified, size: 16),
                      label: Text('Docs Verified'),
                    )
                  else
                    const Chip(
                      avatar: Icon(Icons.pending, size: 16),
                      label: Text('Docs Pending'),
                    ),
                  Chip(
                    label: Text(ticket.assignedEmployeeName ?? 'Unassigned'),
                  ),
                  Chip(label: Text(dateLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
