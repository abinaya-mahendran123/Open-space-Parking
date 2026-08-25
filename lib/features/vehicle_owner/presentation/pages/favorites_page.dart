import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_listing_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_empty_state.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';
    final favoritesAsync = ref.watch(favoritesProvider(vehicleOwnerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
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
            return VehicleOwnerEmptyState(
              icon: Icons.favorite_border,
              title: 'No favorites yet',
              message: 'Tap the heart on any parking to save it here.',
              actionLabel: 'Browse parking',
              onAction: () => context.go(RoutePaths.vehicleOwnerDashboard),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(favoritesProvider(vehicleOwnerId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final listing = favorites[index].listing;
                if (listing == null) return const SizedBox.shrink();

                return ParkingListingCard(
                  listing: listing,
                  compact: true,
                  onTap: () => context.push(
                    RoutePaths.vehicleOwnerParkingDetail(listing.id),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
