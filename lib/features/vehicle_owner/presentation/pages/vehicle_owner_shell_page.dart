import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/widgets/layout/app_shell_scaffold.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/favorites_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/my_bookings_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/parking_search_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/vehicle_owner_dashboard_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/vehicle_owner_profile_page.dart';

class VehicleOwnerShellPage extends ConsumerStatefulWidget {
  const VehicleOwnerShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<VehicleOwnerShellPage> createState() =>
      _VehicleOwnerShellPageState();
}

class _VehicleOwnerShellPageState extends ConsumerState<VehicleOwnerShellPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant VehicleOwnerShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  static const _pages = [
    VehicleOwnerDashboardPage(),
    ParkingSearchPage(),
    FavoritesPage(),
    MyBookingsPage(),
    VehicleOwnerProfilePage(),
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            selectedIcon: Icon(Icons.near_me),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'History',
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
