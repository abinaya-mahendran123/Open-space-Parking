import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_listing_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/rating_stars.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';
    final favoritesAsync = ref.watch(favoritesProvider(vehicleOwnerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.vehicleOwnerSearch),
        ),
        actions: const [VehicleOwnerAppBarActions()],
      ),
      body: favoritesAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading favorites...'),
        error: (_, __) => AppErrorWidget(
          message: 'Failed to load favorites',
          onRetry: () => ref.invalidate(favoritesProvider(vehicleOwnerId)),
        ),
        data: (favorites) {
          if (favorites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No favorites yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart icon on any parking space to save it here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.tonal(
                      onPressed: () => context.go(RoutePaths.vehicleOwnerSearch),
                      child: const Text('Browse Parking'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(favoritesProvider(vehicleOwnerId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                final listing = favorite.listing;
                if (listing == null) return const SizedBox.shrink();

                return Stack(
                  children: [
                    ParkingListingCard(
                      listing: listing,
                      onTap: () => context.push(
                        RoutePaths.vehicleOwnerParkingDetail(listing.id),
                      ),
                    ),
                    if (listing.reviewCount > 0)
                      Positioned(
                        top: 24,
                        right: 48,
                        child: RatingStars(
                          rating: listing.averageRating,
                          size: 12,
                          showValue: true,
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
