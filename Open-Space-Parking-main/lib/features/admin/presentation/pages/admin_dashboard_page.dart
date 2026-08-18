import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/animations/app_fade_slide.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/layout/app_page_header.dart';
import 'package:open_space_parking/core/widgets/layout/responsive_page.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_skeleton.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';
import 'package:open_space_parking/features/admin/presentation/widgets/admin_stat_card.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatisticsProvider);
    final email = ref.watch(authStateProvider).session?.email ?? 'Admin';
    final crossAxisCount = responsiveGridCount(context);
    final palette = AppColors.statPalette(Theme.of(context).brightness);

    return statsAsync.when(
      loading: () => AppLoadingWidget(
        message: 'Loading dashboard...',
        useSkeleton: true,
        skeleton: AppSkeleton.statGrid(context, count: 8),
      ),
      error: (_, __) => AppErrorWidget(
        message: 'Failed to load dashboard statistics.',
        onRetry: () => ref.invalidate(adminStatisticsProvider),
      ),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatisticsProvider);
            ref.invalidate(adminTicketsProvider);
          },
          child: ResponsivePage(
            maxWidth: responsiveMaxWidth(context),
            scrollable: true,
            child: AppFadeSlide(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(
                    title: 'Admin Dashboard',
                    subtitle: 'Welcome back, $email',
                    animate: false,
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: context.isMobile ? 1.35 : 1.5,
                    children: [
                      AdminStatCard(
                        label: 'Total Tickets',
                        value: '${stats.totalTickets}',
                        icon: Icons.confirmation_number_outlined,
                        color: palette[0],
                      ),
                      AdminStatCard(
                        label: 'Submitted',
                        value: '${stats.submittedCount}',
                        icon: Icons.inbox_outlined,
                        color: palette[1],
                      ),
                      AdminStatCard(
                        label: 'Under Review',
                        value: '${stats.underReviewCount}',
                        icon: Icons.hourglass_top_outlined,
                        color: palette[2],
                      ),
                      AdminStatCard(
                        label: 'Approved',
                        value: '${stats.approvedCount}',
                        icon: Icons.check_circle_outline,
                        color: palette[3],
                      ),
                      AdminStatCard(
                        label: 'Rejected',
                        value: '${stats.rejectedCount}',
                        icon: Icons.cancel_outlined,
                        color: palette[4],
                      ),
                      AdminStatCard(
                        label: 'Unassigned',
                        value: '${stats.unassignedTickets}',
                        icon: Icons.person_off_outlined,
                        color: palette[5],
                      ),
                      AdminStatCard(
                        label: 'Docs Pending',
                        value: '${stats.documentsPendingVerification}',
                        icon: Icons.folder_shared_outlined,
                        color: palette[6],
                      ),
                      AdminStatCard(
                        label: 'Active Employees',
                        value: '${stats.activeEmployees}',
                        icon: Icons.badge_outlined,
                        color: palette[7],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const AppSectionHeader(title: 'Quick Actions'),
                  AdminQuickActions(
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go(RoutePaths.adminTickets),
                        icon: const Icon(Icons.construction),
                        label: const Text('Construction Requests'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go(RoutePaths.adminEmployees),
                        icon: const Icon(Icons.group_add),
                        label: const Text('Employee Management'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go(RoutePaths.adminStatistics),
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('View Charts'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
