import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/layout/app_shell_scaffold.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_employees_page.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_statistics_page.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_tickets_page.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';

class AdminShellPage extends ConsumerStatefulWidget {
  const AdminShellPage({
    super.key,
    this.initialIndex = 0,
    this.ticketStatusFilter,
  });

  final int initialIndex;
  final String? ticketStatusFilter;

  @override
  ConsumerState<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends ConsumerState<AdminShellPage> {
  late int _currentIndex;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.confirmation_number_outlined),
      selectedIcon: Icon(Icons.confirmation_number),
      label: 'Tickets',
    ),
    NavigationDestination(
      icon: Icon(Icons.badge_outlined),
      selectedIcon: Icon(Icons.badge),
      label: 'Employees',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Statistics',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Apply status filter from dashboard card tap (after first frame)
    if (widget.ticketStatusFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyStatusFilter(widget.ticketStatusFilter!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AdminShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() => _currentIndex = widget.initialIndex);
    }
    if (oldWidget.ticketStatusFilter != widget.ticketStatusFilter &&
        widget.ticketStatusFilter != null) {
      _applyStatusFilter(widget.ticketStatusFilter!);
    }
  }

  void _applyStatusFilter(String statusParam) {
    RequestStatus? status;
    switch (statusParam) {
      case 'submitted':
        status = RequestStatus.submitted;
        break;
      case 'under_review':
        status = RequestStatus.underReview;
        break;
      case 'approved':
        status = RequestStatus.approved;
        break;
      case 'rejected':
        status = RequestStatus.rejected;
        break;
      case 'unassigned':
      case 'docs_pending':
        // No direct status for these — show all tickets so user can see context
        status = null;
        break;
    }
    ref.read(ticketFilterProvider.notifier).setStatus(status);
  }

  void _onSelect(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go(RoutePaths.adminPortal);
        break;
      case 1:
        context.go(RoutePaths.adminTickets);
        break;
      case 2:
        context.go(RoutePaths.adminEmployees);
        break;
      case 3:
        context.go(RoutePaths.adminStatistics);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = context.isDesktop || context.isTablet;
    final pages = [
      const AdminDashboardPage(),
      const AdminTicketsPage(),
      const AdminEmployeesPage(),
      const AdminStatisticsPage(),
    ];

    final body = pages[_currentIndex];

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Portal'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              onPressed: () => ref.read(authStateProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.confirmation_number_outlined),
                  selectedIcon: Icon(Icons.confirmation_number),
                  label: Text('Tickets'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.badge_outlined),
                  selectedIcon: Icon(Icons.badge),
                  label: Text('Employees'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Statistics'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return AppShellScaffold(
      appBar: AppBar(
        title: const Text('Admin Portal'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: body,
      selectedIndex: _currentIndex,
      onDestinationSelected: _onSelect,
      destinations: _destinations,
    );
  }
}
