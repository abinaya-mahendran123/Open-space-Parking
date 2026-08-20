import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/providers/employee_providers.dart';
import 'package:open_space_parking/features/employee/presentation/widgets/employee_sub_page_frame.dart';

class EmployeeCompletedPage extends ConsumerWidget {
  const EmployeeCompletedPage({super.key});

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = ref.watch(authStateProvider).session?.userId ?? '';
    final projectsAsync = ref.watch(completedProjectsProvider(employeeId));

    return EmployeeSubPageFrame(
      title: 'Completed Projects',
      child: projectsAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading completed projects...'),
        error: (_, __) => AppErrorWidget(
          message: 'Failed to load completed projects',
          onRetry: () => ref.invalidate(completedProjectsProvider(employeeId)),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return const Center(child: Text('No completed projects yet.'));
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(completedProjectsProvider(employeeId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final completed =
                    project.completedAt ?? project.submittedAt;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.task_alt, color: Colors.teal),
                    title: Text(project.ticketId),
                    subtitle: Text(
                      '${project.ownerDetails.fullName}\nCompleted ${_dateFormat.format(completed.toLocal())}',
                    ),
                    isThreeLine: true,
                    onTap: () => context.push(
                      RoutePaths.employeeTicketDetail(project.ticketId),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
