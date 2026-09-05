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
  late final Set<int> _builtTabs;

  static const _tabPaths = [
    RoutePaths.vehicleOwnerSearch,
    RoutePaths.vehicleOwnerFavorites,
    RoutePaths.vehicleOwnerBookings,
    RoutePaths.vehicleOwnerProfile,
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _tabPaths.length - 1);
    _builtTabs = {_currentIndex};
  }

  @override
  void didUpdateWidget(covariant VehicleOwnerShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      final next = widget.initialIndex.clamp(0, _tabPaths.length - 1);
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

  Widget _pageAt(int index) {
    return switch (index) {
      0 => const ParkingSearchPage(),
      1 => const FavoritesPage(),
      2 => const MyBookingsPage(),
      _ => const VehicleOwnerProfilePage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Offstage (not IndexedStack) keeps tab state without remounting the map,
    // and fully hides inactive tabs so map overlays cannot bleed through.
    return AppShellScaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < _tabPaths.length; i++)
            if (_builtTabs.contains(i))
              Offstage(
                offstage: _currentIndex != i,
                child: TickerMode(
                  enabled: _currentIndex == i,
                  child: _pageAt(i),
                ),
              ),
        ],
      ),
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
          label: 'Account',
        ),
      ],
    );
  }
}
