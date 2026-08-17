import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant LandOwnerShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  static const _pages = [
    LandOwnerDashboardPage(),
    RequestHistoryPage(),
    LandOwnerNotificationsPage(),
    LandOwnerProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
            label: 'Profile',
          ),
      ],
    );
  }
}
