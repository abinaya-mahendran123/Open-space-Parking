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
import 'package:open_space_parking/features/employee/presentation/providers/employee_providers.dart';

class EmployeeShellPage extends ConsumerStatefulWidget {
  const EmployeeShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<EmployeeShellPage> createState() => _EmployeeShellPageState();
}

class _EmployeeShellPageState extends ConsumerState<EmployeeShellPage> {
  static const _pages = [
    EmployeeDashboardPage(),
    EmployeeAssignedPage(),
    EmployeeCompletedPage(),
    EmployeeNotificationsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(employeeShellTabProvider.notifier).state = widget.initialIndex;
    });
  }

  @override
  void didUpdateWidget(covariant EmployeeShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      ref.read(employeeShellTabProvider.notifier).state = widget.initialIndex;
    }
  }

  void _onSelect(int index) {
    ref.read(employeeShellTabProvider.notifier).state = index;
  }

  Future<void> _logout() async {
    ref.read(employeeShellTabProvider.notifier).state = 0;
    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;
    context.go(RoutePaths.authEntry);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(employeeShellTabProvider);
    final isWide = context.isDesktop || context.isTablet;

    final appBar = AppBar(
      title: const Text('Employee Portal'),
      actions: [
        IconButton(
          tooltip: 'Logout',
          onPressed: _logout,
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
              selectedIndex: currentIndex,
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
            Expanded(child: _pages[currentIndex]),
          ],
        ),
      );
    }

    return AppShellScaffold(
      appBar: appBar,
      body: _pages[currentIndex],
      selectedIndex: currentIndex,
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
