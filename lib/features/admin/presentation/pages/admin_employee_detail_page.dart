import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';

class AdminEmployeeDetailPage extends ConsumerWidget {
  const AdminEmployeeDetailPage({super.key, required this.employeeId});

  static final _dateFormat = DateFormat('dd MMM yyyy');

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(adminEmployeesProvider);
    final ticketsAsync = ref.watch(adminEmployeeTicketsProvider(employeeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Employee Work')),
      body: employeesAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading employee...'),
        error: (_, __) => AppErrorWidget(
          message: 'Failed to load employee',
          onRetry: () => ref.invalidate(adminEmployeesProvider),
        ),
        data: (employees) {
          final employeeIndex =
              employees.indexWhere((item) => item.id == employeeId);
          if (employeeIndex == -1) {
            return const Center(child: Text('Employee not found.'));
          }
          final employee = employees[employeeIndex];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminEmployeesProvider);
              ref.invalidate(adminEmployeeTicketsProvider(employeeId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Text(
                            employee.fullName.isNotEmpty
                                ? employee.fullName[0].toUpperCase()
                                : 'E',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.fullName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(employee.phone),
                              if (!employee.isActive) ...[
                                const SizedBox(height: 8),
                                Chip(
                                  label: const Text('Inactive'),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Assigned Work',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ticketsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => AppErrorWidget(
                    message: 'Failed to load assigned work',
                    onRetry: () =>
                        ref.invalidate(adminEmployeeTicketsProvider(employeeId)),
                  ),
                  data: (tickets) {
                    if (tickets.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No tickets assigned to this employee yet.'),
                        ),
                      );
                    }

                    return Column(
                      children: tickets.map((ticket) {
                        return _AssignedTicketCard(
                          ticket: ticket,
                          dateLabel: _dateFormat.format(
                            ticket.submittedAt.toLocal(),
                          ),
                          onTap: () => context.push(
                            '${RoutePaths.adminTicketDetail(ticket.ticketId)}?readonly=true',
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssignedTicketCard extends StatelessWidget {
  const _AssignedTicketCard({
    required this.ticket,
    required this.dateLabel,
    required this.onTap,
  });

  final LandOwnerRequest ticket;
  final String dateLabel;
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
                  Chip(label: Text(ticket.status.label)),
                ],
              ),
              const SizedBox(height: 4),
              Text(ticket.ownerDetails.fullName),
              Text(ticket.requestType.label),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: ticket.constructionProgress / 100,
              ),
              const SizedBox(height: 4),
              Text(
                'Progress ${ticket.constructionProgress}% • $dateLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
