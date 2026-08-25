import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/booking_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.vehicleOwnerSearch),
        ),
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No bookings yet. Search for parking and book your first space.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final live = bookings.where((b) => b.isQrLive).toList();
          final past = bookings.where((b) => !b.isQrLive).toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (live.isNotEmpty) ...[
                  Text(
                    'Parking QR (open until payment)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the QR icon to show your ticket to security.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ...live.map(
                    (booking) => BookingCard(
                      booking: booking,
                      onTap: () => _openTicket(context, booking),
                      onShowQr: () => _openTicket(context, booking),
                    ),
                  ),
                  if (past.isNotEmpty) const SizedBox(height: 8),
                ],
                if (past.isNotEmpty) ...[
                  Text(
                    live.isNotEmpty ? 'Past bookings' : 'Booking history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
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
