import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/layout/app_shell_scaffold.dart';
import 'package:open_space_parking/features/account/presentation/pages/role_account_pages.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_employees_page.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_statistics_page.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_tickets_page.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';
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

  static const _pages = [
    AdminDashboardPage(),
    AdminTicketsPage(),
    AdminEmployeesPage(),
    AdminStatisticsPage(),
  ];

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
    _currentIndex = widget.initialIndex.clamp(0, _pages.length - 1);
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
      setState(
        () => _currentIndex = widget.initialIndex.clamp(0, _pages.length - 1),
      );
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
      case 'under_review':
        status = RequestStatus.underReview;
      case 'approved':
        status = RequestStatus.approved;
      case 'rejected':
        status = RequestStatus.rejected;
      case 'unassigned':
      case 'docs_pending':
        status = null;
    }
    ref.read(ticketFilterProvider.notifier).setStatus(status);
  }

  void _onSelect(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go(RoutePaths.adminPortal);
      case 1:
        context.go(RoutePaths.adminTickets);
      case 2:
        context.go(RoutePaths.adminEmployees);
      case 3:
        context.go(RoutePaths.adminStatistics);
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('My Account')),
          body: const AdminProfilePage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = context.isDesktop || context.isTablet;
    final safeIndex = _currentIndex.clamp(0, _pages.length - 1);
    final body = _pages[safeIndex];
    final atHome = safeIndex == 0;

    final appBar = AppBar(
      title: const Text('Admin Portal'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline),
            label: const Text('Profile'),
          ),
        ),
      ],
    );

    Widget wrap(Widget child) {
      return PopScope(
        canPop: atHome,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || atHome) return;
          _onSelect(0);
        },
        child: child,
      );
    }

    if (isWide) {
      return wrap(
        Scaffold(
          appBar: appBar,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: safeIndex,
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
        ),
      );
    }

    return AppShellScaffold(
      appBar: appBar,
      body: body,
      selectedIndex: safeIndex,
      onDestinationSelected: _onSelect,
      destinations: _destinations,
    );
  }
}
