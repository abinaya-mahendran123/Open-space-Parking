import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/layout/app_shell_scaffold.dart';
import 'package:open_space_parking/features/account/presentation/pages/role_account_pages.dart';
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

  static const _tabPaths = [
    RoutePaths.employeeDashboard,
    RoutePaths.employeeAssigned,
    RoutePaths.employeeCompleted,
    RoutePaths.employeeNotifications,
  ];

  late final Set<int> _builtTabs;

  @override
  void initState() {
    super.initState();
    final index = widget.initialIndex.clamp(0, _pages.length - 1);
    _builtTabs = {index};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(employeeShellTabProvider.notifier).state = index;
    });
  }

  @override
  void didUpdateWidget(covariant EmployeeShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      final index = widget.initialIndex.clamp(0, _pages.length - 1);
      setState(() => _builtTabs.add(index));
      ref.read(employeeShellTabProvider.notifier).state = index;
    }
  }

  void _onSelect(int index) {
    final next = index.clamp(0, _pages.length - 1);
    setState(() => _builtTabs.add(next));
    ref.read(employeeShellTabProvider.notifier).state = next;
    final target = _tabPaths[next];
    if (GoRouterState.of(context).uri.path != target) {
      context.go(target);
    }
  }

  Widget _tabBody(int safeIndex) {
    return IndexedStack(
      index: safeIndex,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < _pages.length; i++)
          if (_builtTabs.contains(i))
            _pages[i]
          else
            const SizedBox.shrink(),
      ],
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('My Account')),
          body: const EmployeeProfilePage(),
        ),
      ),
    );
  }

  Widget _wrapBackHandling({required int currentIndex, required Widget child}) {
    final atHome = currentIndex == 0;
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || atHome) return;
        _onSelect(0);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(employeeShellTabProvider);
    final safeIndex = currentIndex.clamp(0, _pages.length - 1);
    final isWide = context.isDesktop || context.isTablet;

    final appBar = AppBar(
      title: const Text('Employee Portal'),
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

    if (isWide) {
      return _wrapBackHandling(
        currentIndex: safeIndex,
        child: Scaffold(
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
              Expanded(child: _tabBody(safeIndex)),
            ],
          ),
        ),
      );
    }

    return AppShellScaffold(
      appBar: appBar,
      body: _tabBody(safeIndex),
      selectedIndex: safeIndex,
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
