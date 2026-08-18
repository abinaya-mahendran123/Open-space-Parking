import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class ParkingTicketPage extends ConsumerWidget {
  const ParkingTicketPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Ticket'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(RoutePaths.vehicleOwnerBookings),
        ),
      ),
      body: bookingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading ticket...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load ticket',
          onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Ticket not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (booking.assignedSlot != null)
                Text(
                  'SLOT ${booking.assignedSlot}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              const SizedBox(height: 8),
              Text(
                booking.vehicleNumber,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                booking.parkingType.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Center(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: booking.displayQr,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                booking.displayQr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                booking.isAwaitingPayment
                    ? 'Security already scanned. Pay to release your slot.'
                    : 'Park your car. On return, security will scan this QR to calculate duration.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (booking.isAwaitingPayment)
                FilledButton(
                  onPressed: () => context.push(
                    RoutePaths.vehicleOwnerPayBooking(booking.id),
                  ),
                  child: Text(
                    'Pay ₹${booking.amountDue!.toStringAsFixed(0)}',
                  ),
                )
              else
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(bookingDetailProvider(bookingId)),
                  child: const Text('Refresh status'),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(RoutePaths.vehicleOwnerBookings),
                child: const Text('My bookings'),
              ),
            ],
          );
        },
      ),
    );
  }
}
