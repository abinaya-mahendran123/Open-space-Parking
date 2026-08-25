import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_skeleton.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_listing_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';

class VehicleOwnerDashboardPage extends ConsumerWidget {
  const VehicleOwnerDashboardPage({super.key});

  void _openParking(BuildContext context, ParkingListing listing) {
    final key = ParkingListingCard.routeKeyFor(listing);
    if (key.isEmpty) return;
    context.push(RoutePaths.vehicleOwnerParkingDetail(key));
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
        title: const Text('Parking'),
        actions: const [VehicleOwnerAppBarActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(parkingListingsProvider),
        child: listingsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Hello, $name',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              AppLoadingWidget(
                message: 'Loading parking spaces...',
                useSkeleton: true,
                skeleton: AppSkeleton.parkingCards(),
              ),
            ],
          ),
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorWidget(
                message: 'Could not load parking spaces.',
                onRetry: () => ref.invalidate(parkingListingsProvider),
              ),
            ],
          ),
          data: (listings) {
            final liveBooking = bookingsAsync.maybeWhen(
              data: (bookings) {
                final live = bookings.where((b) => b.isQrLive).toList();
                return live.isEmpty ? null : live.first;
              },
              orElse: () => null,
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                if (liveBooking != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ListTile(
                      leading: const Icon(Icons.qr_code_2),
                      title: const Text('Active parking'),
                      subtitle: Text(
                        'Slot ${liveBooking.assignedSlot ?? '-'} · ${liveBooking.displayParkingName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        RoutePaths.vehicleOwnerParkingTicket(liveBooking.id),
                      ),
                    ),
                  ),
                Text(
                  'Hello, $name',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (listings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_parking_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No parking spaces nearby yet.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Pull down to refresh or use the Nearby tab for map search.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...listings.map(
                    (listing) => ParkingListingCard(
                      listing: listing,
                      compact: true,
                      onTap: () => _openParking(context, listing),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
