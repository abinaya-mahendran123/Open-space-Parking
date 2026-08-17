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

class AdminTicketsPage extends ConsumerWidget {
  const AdminTicketsPage({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(ticketFilterProvider);
    final ticketsAsync = ref.watch(adminTicketsProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search ticket, owner, phone, employee...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: filter.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              ref.read(ticketFilterProvider.notifier).setSearch(''),
                        )
                      : null,
                ),
                onChanged: (v) =>
                    ref.read(ticketFilterProvider.notifier).setSearch(v),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All Status'),
                      selected: filter.status == null,
                      onSelected: (_) =>
                          ref.read(ticketFilterProvider.notifier).setStatus(null),
                    ),
                    const SizedBox(width: 8),
                    ...RequestStatus.values.map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status.label),
                          selected: filter.status == status,
                          onSelected: (_) => ref
                              .read(ticketFilterProvider.notifier)
                              .setStatus(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All Types'),
                      selected: filter.requestType == null,
                      onSelected: (_) =>
                          ref.read(ticketFilterProvider.notifier).setType(null),
                    ),
                    const SizedBox(width: 8),
                    ...LandOwnerRequestType.values.map(
                      (type) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type.label),
                          selected: filter.requestType == type,
                          onSelected: (_) =>
                              ref.read(ticketFilterProvider.notifier).setType(type),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Unassigned'),
                      selected: filter.unassignedOnly,
                      onSelected: (v) => ref
                          .read(ticketFilterProvider.notifier)
                          .setUnassignedOnly(v),
                    ),
                  ],
                ),
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
                return const Center(child: Text('No tickets match your filters.'));
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
                      dateLabel: dateFormat.format(ticket.submittedAt.toLocal()),
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
              Text('${ticket.ownerDetails.fullName} • ${ticket.ownerDetails.phone}'),
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
                    label: Text(
                      ticket.assignedEmployeeName ?? 'Unassigned',
                    ),
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
