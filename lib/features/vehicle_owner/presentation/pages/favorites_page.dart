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

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
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
              title: 'No saved parking',
              message: 'Save your preferred parking for quick access later.',
              actionLabel: 'Find parking',
              onAction: () => context.go(RoutePaths.vehicleOwnerSearch),
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
