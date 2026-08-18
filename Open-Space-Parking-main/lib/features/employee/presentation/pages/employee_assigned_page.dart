import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/providers/employee_providers.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';

class EmployeeAssignedPage extends ConsumerWidget {
  const EmployeeAssignedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = ref.watch(authStateProvider).session?.userId ?? '';
    final projectsAsync = ref.watch(assignedProjectsProvider(employeeId));
    final dateFormat = DateFormat('dd MMM yyyy');

    return projectsAsync.when(
      loading: () => const AppLoadingWidget(message: 'Loading assigned projects...'),
      error: (_, __) => AppErrorWidget(
        message: 'Failed to load assigned projects',
        onRetry: () => ref.invalidate(assignedProjectsProvider(employeeId)),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return const Center(child: Text('No assigned projects yet.'));
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(assignedProjectsProvider(employeeId)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _ProjectCard(
                project: project,
                dateLabel: dateFormat.format(project.submittedAt.toLocal()),
                onTap: () => context.push(
                  RoutePaths.employeeTicketDetail(project.ticketId),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.dateLabel,
    required this.onTap,
  });

  final LandOwnerRequest project;
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
                      project.ticketId,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text(project.status.label)),
                ],
              ),
              Text(project.ownerDetails.fullName),
              Text(project.requestType.label),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: project.constructionProgress / 100,
              ),
              const SizedBox(height: 4),
              Text(
                'Progress ${project.constructionProgress}% • $dateLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
