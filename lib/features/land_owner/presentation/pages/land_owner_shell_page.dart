import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/layout/app_shell_scaffold.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/land_owner_dashboard_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/land_owner_notifications_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/land_owner_profile_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/request_history_page.dart';

class LandOwnerShellPage extends ConsumerStatefulWidget {
  const LandOwnerShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<LandOwnerShellPage> createState() => _LandOwnerShellPageState();
}

class _LandOwnerShellPageState extends ConsumerState<LandOwnerShellPage> {
  late int _currentIndex;
  late final Set<int> _builtTabs;

  static const _pages = [
    LandOwnerDashboardPage(),
    RequestHistoryPage(),
    LandOwnerNotificationsPage(),
    LandOwnerProfilePage(),
  ];

  static const _tabPaths = [
    RoutePaths.landOwnerDashboard,
    RoutePaths.landOwnerHistory,
    RoutePaths.landOwnerNotifications,
    RoutePaths.landOwnerProfile,
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _pages.length - 1);
    _builtTabs = {_currentIndex};
  }

  @override
  void didUpdateWidget(covariant LandOwnerShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      final next = widget.initialIndex.clamp(0, _pages.length - 1);
      setState(() {
        _currentIndex = next;
        _builtTabs.add(next);
      });
    }
  }

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      _builtTabs.add(index);
    });
    final target = _tabPaths[index.clamp(0, _tabPaths.length - 1)];
    if (GoRouterState.of(context).uri.path != target) {
      context.go(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      body: IndexedStack(
        index: _currentIndex,
        sizing: StackFit.expand,
        children: [
          for (var i = 0; i < _pages.length; i++)
            if (_builtTabs.contains(i))
              _pages[i]
            else
              const SizedBox.shrink(),
        ],
      ),
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Notifications',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Account',
        ),
      ],
    );
  }
}
