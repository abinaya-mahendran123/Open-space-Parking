import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/cards/app_stat_card.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/layout/app_page_header.dart';
import 'package:open_space_parking/core/widgets/layout/responsive_page.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/providers/employee_providers.dart';

class EmployeeDashboardPage extends ConsumerWidget {
  const EmployeeDashboardPage({super.key});

  static const double _statCellHeight = 112;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = ref.watch(
      authStateProvider.select((state) => state.session?.userId ?? ''),
    );
    final welcomeNameAsync = ref.watch(employeeWelcomeNameProvider);
    final statsAsync = ref.watch(employeeDashboardStatsProvider(employeeId));

    return ResponsivePage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPageHeader(
            title: 'Field Dashboard',
            subtitle: welcomeNameAsync.when(
              data: (name) => 'Welcome, $name',
              loading: () => 'Welcome',
              error: (_, __) => 'Welcome',
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          statsAsync.when(
            loading: () => const AppLoadingWidget(
              message: 'Loading dashboard...',
            ),
            error: (_, __) => AppErrorWidget(
              message: 'Failed to load dashboard data.',
              onRetry: () =>
                  ref.invalidate(employeeDashboardStatsProvider(employeeId)),
            ),
            data: (stats) {
              final inProgress = stats.assigned
                  .where((p) => p.constructionProgress > 0)
                  .length;
              final crossAxisCount = context.isMobile ? 2 : 4;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = AppSpacing.md;
                      final cellWidth = (constraints.maxWidth -
                              spacing * (crossAxisCount - 1)) /
                          crossAxisCount;
                      final aspectRatio = cellWidth / _statCellHeight;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: aspectRatio,
                        children: [
                          AppStatCard(
                            label: 'Assigned',
                            value: '${stats.assigned.length}',
                            icon: Icons.assignment_outlined,
                            onTap: () => ref
                                .read(employeeShellTabProvider.notifier)
                                .state = 1,
                          ),
                          AppStatCard(
                            label: 'In Progress',
                            value: '$inProgress',
                            icon: Icons.construction_outlined,
                            onTap: () => ref
                                .read(employeeShellTabProvider.notifier)
                                .state = 1,
                          ),
                          AppStatCard(
                            label: 'Completed',
                            value: '${stats.completedCount}',
                            icon: Icons.task_alt_outlined,
                            onTap: () => ref
                                .read(employeeShellTabProvider.notifier)
                                .state = 2,
                          ),
                          AppStatCard(
                            label: 'Notifications',
                            value: '${stats.unreadCount}',
                            icon: Icons.notifications_outlined,
                            onTap: () => ref
                                .read(employeeShellTabProvider.notifier)
                                .state = 3,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
