import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/booking_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_empty_state.dart';

class MyBookingsPage extends ConsumerWidget {
  const MyBookingsPage({super.key});

  void _openTicket(BuildContext context, Booking booking) {
    context.push(RoutePaths.vehicleOwnerParkingTicket(booking.id));
  }

  void _openDetail(BuildContext context, Booking booking) {
    context.push(RoutePaths.vehicleOwnerBookingDetail(booking.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';
    final bookingsAsync =
        ref.watch(vehicleOwnerBookingsProvider(vehicleOwnerId));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        actions: const [VehicleOwnerAppBarActions()],
      ),
      body: bookingsAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading bookings...'),
        error: (_, __) => AppErrorWidget(
          message: 'Failed to load bookings',
          onRetry: () =>
              ref.invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId)),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return VehicleOwnerEmptyState(
              icon: Icons.history,
              title: 'No bookings yet',
              message: 'Find a parking space near you.',
              actionLabel: 'Find parking',
              onAction: () => context.go(RoutePaths.vehicleOwnerSearch),
            );
          }

          final live = bookings.where((b) => b.isQrLive).toList();
          final past = bookings.where((b) => !b.isQrLive).toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId)),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (live.isNotEmpty) ...[
                  Text(
                    'Active',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...live.map(
                    (booking) => BookingCard(
                      booking: booking,
                      onTap: () => _openTicket(context, booking),
                      onShowQr: () => _openTicket(context, booking),
                    ),
                  ),
                  if (past.isNotEmpty) const SizedBox(height: AppSpacing.md),
                ],
                if (past.isNotEmpty) ...[
                  Text(
                    'Past',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...past.map(
                    (booking) => BookingCard(
                      booking: booking,
                      onTap: () => _openDetail(context, booking),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
