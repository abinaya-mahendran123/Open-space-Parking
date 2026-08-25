import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class ParkingTicketPage extends ConsumerStatefulWidget {
  const ParkingTicketPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ParkingTicketPage> createState() => _ParkingTicketPageState();
}

class _ParkingTicketPageState extends ConsumerState<ParkingTicketPage> {
  Timer? _pollTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(bookingDetailProvider(widget.bookingId));
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  String _statusHint(Booking booking) {
    if (booking.isAwaitingPayment) return 'Pay to release your slot';
    if (booking.isParked) return 'Show this QR when you leave';
    if (booking.isAwaitingEntry) return 'Show this QR at the gate';
    if (booking.status == BookingStatus.completed) return 'Payment complete';
    return 'Show this QR to security';
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking QR'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(RoutePaths.vehicleOwnerBookings),
        ),
      ),
      body: bookingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load ticket',
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Ticket not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                child: Column(
                  children: [
                    Text(
                      booking.assignedSlot != null && booking.assignedSlot! > 0
                          ? 'Slot ${booking.assignedSlot}'
                          : 'Slot pending',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.shortDisplayParkingName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.vehicleNumber,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusHint(booking),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (booking.isParked) ...[
                      const SizedBox(height: 4),
                      Text(
                        booking.elapsedClock(),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (booking.isQrLive) ...[
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: booking.displayQr,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
              if (booking.isAwaitingPayment) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '₹${booking.amountDue!.toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  booking.billedDurationLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => context.push(
                    RoutePaths.vehicleOwnerPayBooking(booking.id),
                  ),
                  icon: const Icon(Icons.payment),
                  label: Text('Pay ₹${booking.amountDue!.toStringAsFixed(0)}'),
                ),
              ] else if (booking.status == BookingStatus.completed) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => context.go(
                    RoutePaths.vehicleOwnerBookingReceipt(booking.id),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('View receipt'),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(bookingDetailProvider(widget.bookingId)),
                  child: const Text('Refresh'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
