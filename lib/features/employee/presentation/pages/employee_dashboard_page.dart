import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/animations/app_fade_slide.dart';
import 'package:open_space_parking/core/widgets/cards/app_action_card.dart';
import 'package:open_space_parking/core/widgets/cards/app_stat_card.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/layout/app_page_header.dart';
import 'package:open_space_parking/core/widgets/layout/responsive_page.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_skeleton.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/providers/employee_providers.dart';

class EmployeeDashboardPage extends ConsumerWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = ref.watch(authStateProvider).session?.userId ?? '';
    final email = ref.watch(authStateProvider).session?.email ?? 'Employee';
    final assignedAsync = ref.watch(assignedProjectsProvider(employeeId));
    final completedAsync = ref.watch(completedProjectsProvider(employeeId));
    final unreadAsync = ref.watch(employeeUnreadCountProvider(employeeId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(assignedProjectsProvider(employeeId));
        ref.invalidate(completedProjectsProvider(employeeId));
        ref.invalidate(employeeUnreadCountProvider(employeeId));
      },
      child: ResponsivePage(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Field Dashboard',
              subtitle: 'Welcome, $email',
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            assignedAsync.when(
              loading: () => AppLoadingWidget(
                useSkeleton: true,
                skeleton: Column(
                  children: [
                    AppSkeleton.statGrid(context, count: 4),
                    const SizedBox(height: AppSpacing.lg),
                    AppSkeleton.actionCards(count: 2),
                  ],
                ),
              ),
              error: (_, __) => AppErrorWidget(
                message: 'Failed to load your projects.',
                onRetry: () =>
                    ref.invalidate(assignedProjectsProvider(employeeId)),
              ),
              data: (assigned) {
                final completedCount =
                    completedAsync.valueOrNull?.length ?? 0;
                final unread = unreadAsync.valueOrNull ?? 0;
                final inProgress = assigned
                    .where((p) => p.constructionProgress > 0)
                    .length;
                final crossAxisCount = context.isMobile ? 2 : 4;

                return AppFadeSlide(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.8,
                        children: [
                          AppStatCard(
                            label: 'Assigned',
                            value: '${assigned.length}',
                            icon: Icons.assignment_outlined,
                          ),
                          AppStatCard(
                            label: 'In Progress',
                            value: '$inProgress',
                            icon: Icons.construction_outlined,
                          ),
                          AppStatCard(
                            label: 'Completed',
                            value: '$completedCount',
                            icon: Icons.task_alt_outlined,
                          ),
                          AppStatCard(
                            label: 'Notifications',
                            value: '$unread',
                            icon: Icons.notifications_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      const AppSectionHeader(title: 'Quick Actions'),
                      AppStaggeredList(
                        children: [
                          AppActionCard(
                            icon: Icons.assignment_outlined,
                            title: 'Assigned Projects',
                            subtitle: 'View and update active construction tickets.',
                            onTap: () => context.go(RoutePaths.employeeAssigned),
                          ),
                          AppActionCard(
                            icon: Icons.task_alt_outlined,
                            title: 'Completed Projects',
                            subtitle: 'Browse finished parking implementations.',
                            onTap: () => context.go(RoutePaths.employeeCompleted),
                          ),
                          AppActionCard(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Alerts for assignments and updates.',
                            onTap: () =>
                                context.go(RoutePaths.employeeNotifications),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
