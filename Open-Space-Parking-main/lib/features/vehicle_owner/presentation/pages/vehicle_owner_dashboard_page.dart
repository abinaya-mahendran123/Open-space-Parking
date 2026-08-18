import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/animations/app_fade_slide.dart';
import 'package:open_space_parking/core/widgets/cards/app_action_card.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/layout/app_page_header.dart';
import 'package:open_space_parking/core/widgets/layout/responsive_page.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_skeleton.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_listing_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';

class VehicleOwnerDashboardPage extends ConsumerWidget {
  const VehicleOwnerDashboardPage({super.key});

  Future<void> _openParking(
    BuildContext context,
    WidgetRef ref,
    ParkingListing listing,
  ) async {
    final opened = await ref.read(mapsRepositoryProvider).openNavigation(
          DirectionsRequest(
            destination: MapCoordinate(
              latitude: listing.latitude,
              longitude: listing.longitude,
            ),
          ),
        );
    if (!opened && context.mounted) {
      // Still open detail even if Maps fails.
    }
    if (context.mounted) {
      context.push(RoutePaths.vehicleOwnerParkingDetail(listing.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final vehicleOwnerId = auth.session?.userId ?? '';
    final listingsAsync = ref.watch(parkingListingsProvider);
    final bookingsAsync = ref.watch(vehicleOwnerBookingsProvider(vehicleOwnerId));
    final name = auth.session?.greetingName ?? 'Driver';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [VehicleOwnerAppBarActions()],
      ),
      body: ResponsivePage(
        maxWidth: 800,
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Hello, $name',
              subtitle: 'Search and book open-space parking near you.',
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            AppStaggeredList(
              children: [
                AppActionCard(
                  icon: Icons.near_me_rounded,
                  title: 'Nearby Parking',
                  subtitle: 'Search on map or list with filters.',
                  onTap: () => context.go(RoutePaths.vehicleOwnerSearch),
                ),
                AppActionCard(
                  icon: Icons.favorite_rounded,
                  title: 'Favorites',
                  subtitle: 'View your saved parking spaces.',
                  onTap: () => context.go(RoutePaths.vehicleOwnerFavorites),
                ),
                AppActionCard(
                  icon: Icons.map_rounded,
                  title: 'Parking Map',
                  subtitle: 'Full-screen map with directions and navigation.',
                  onTap: () => context.push(RoutePaths.nearbyParkingMap),
                ),
                AppActionCard(
                  icon: Icons.bookmark_rounded,
                  title: 'Saved Coordinates',
                  subtitle: 'View and manage saved map locations.',
                  onTap: () => context.push(RoutePaths.savedCoordinates),
                ),
              ],
            ),
            bookingsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (bookings) {
                final active = bookings
                    .where((b) =>
                        b.status == BookingStatus.confirmed ||
                        b.status == BookingStatus.active)
                    .length;
                if (active == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: AppActionCard(
                    icon: Icons.book_online_rounded,
                    title: 'Active Bookings',
                    subtitle: '$active active booking${active == 1 ? '' : 's'}',
                    onTap: () => context.go(RoutePaths.vehicleOwnerBookings),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nearby Parking',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(RoutePaths.vehicleOwnerSearch),
                  child: const Text('See all'),
                ),
              ],
            ),
            listingsAsync.when(
              loading: () => AppLoadingWidget(
                message: 'Loading parking spaces...',
                useSkeleton: true,
                skeleton: AppSkeleton.parkingCards(),
              ),
              error: (_, __) => AppErrorWidget(
                message: 'Could not load parking spaces.',
                onRetry: () => ref.invalidate(parkingListingsProvider),
              ),
              data: (listings) {
                if (listings.isEmpty) {
                  return const SizedBox.shrink();
                }

                final preview = listings.take(3).toList();
                return Column(
                  children: [
                    ...preview.map(
                      (listing) => ParkingListingCard(
                        listing: listing,
                        onTap: () => _openParking(context, ref, listing),
                      ),
                    ),
                    if (listings.length > 3)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () =>
                              context.go(RoutePaths.vehicleOwnerSearch),
                          child: Text('View all ${listings.length} spaces'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
