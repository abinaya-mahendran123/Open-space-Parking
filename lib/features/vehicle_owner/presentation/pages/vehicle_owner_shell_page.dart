import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/layout/app_shell_scaffold.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/favorites_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/my_bookings_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/parking_search_page.dart';
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

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go(RoutePaths.vehicleOwnerSearch);
      case 1:
        context.go(RoutePaths.vehicleOwnerFavorites);
      case 2:
        context.go(RoutePaths.vehicleOwnerBookings);
      case 3:
        context.go(RoutePaths.vehicleOwnerProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      // Avoid IndexedStack for Nearby: its map location FAB / platform view
      // can bleed onto Favorites, History, and Profile while kept alive.
      body: switch (_currentIndex) {
        0 => const ParkingSearchPage(),
        1 => const FavoritesPage(),
        2 => const MyBookingsPage(),
        _ => const VehicleOwnerProfilePage(),
      },
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.local_parking_outlined),
          selectedIcon: Icon(Icons.local_parking),
          label: 'Parking',
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
