import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/layout/app_shell_scaffold.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_assigned_page.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_completed_page.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_dashboard_page.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_notifications_page.dart';

class EmployeeShellPage extends ConsumerStatefulWidget {
  const EmployeeShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<EmployeeShellPage> createState() => _EmployeeShellPageState();
}

class _EmployeeShellPageState extends ConsumerState<EmployeeShellPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant EmployeeShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  void _onSelect(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go(RoutePaths.employeeDashboard);
        break;
      case 1:
        context.go(RoutePaths.employeeAssigned);
        break;
      case 2:
        context.go(RoutePaths.employeeCompleted);
        break;
      case 3:
        context.go(RoutePaths.employeeNotifications);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = context.isDesktop || context.isTablet;
    const pages = [
      EmployeeDashboardPage(),
      EmployeeAssignedPage(),
      EmployeeCompletedPage(),
      EmployeeNotificationsPage(),
    ];
    final body = IndexedStack(index: _currentIndex, children: pages);

    final appBar = AppBar(
      title: const Text('Employee Portal'),
      actions: [
        IconButton(
          tooltip: 'Logout',
          onPressed: () => ref.read(authStateProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
        ),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
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
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: Text('Assigned'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: Text('Completed'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: Text('Alerts'),
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
      appBar: appBar,
      body: body,
      selectedIndex: _currentIndex,
      onDestinationSelected: _onSelect,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Assigned',
        ),
        NavigationDestination(
          icon: Icon(Icons.task_alt_outlined),
          selectedIcon: Icon(Icons.task_alt),
          label: 'Completed',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
      ],
    );
  }
}
