import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
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

  String _headline(Booking booking) {
    final slot = booking.assignedSlot;
    final slotLabel = slot != null && slot > 0 ? 'Slot $slot' : 'Your slot';
    if (booking.isAwaitingPayment) return '$slotLabel — pay now';
    if (booking.isParked) return 'You are parked in $slotLabel';
    if (booking.isAwaitingEntry) return '$slotLabel is booked';
    if (booking.status == BookingStatus.completed) return 'Payment complete';
    return booking.status.label;
  }

  String _statusMessage(Booking booking) {
    final slot = booking.assignedSlot;
    final slotText = slot != null && slot > 0 ? 'Slot $slot' : 'Your slot';
    if (booking.isAwaitingPayment) {
      return 'Security scanned your exit QR. Pay this bill to release $slotText.';
    }
    if (booking.isParked) {
      return 'Session is running in $slotText. Show this same QR to security when you leave.';
    }
    if (booking.isAwaitingEntry) {
      return '$slotText was assigned first come, first served. '
          'Show this QR to security to start your parking session.';
    }
    if (booking.status == BookingStatus.completed) {
      return 'Payment complete. $slotText released.';
    }
    return 'Show this QR to security.';
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final timeFormat = DateFormat('dd MMM yyyy, hh:mm a');

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
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Ticket not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _headline(booking),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        booking.assignedSlot != null && booking.assignedSlot! > 0
                            ? 'SLOT ${booking.assignedSlot}'
                            : 'SLOT PENDING',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigned by first come, first served',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        booking.displayParkingName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoRow('Parking', booking.displayParkingName),
                      _infoRow(
                        'Slot no',
                        booking.assignedSlot != null && booking.assignedSlot! > 0
                            ? '${booking.assignedSlot} (FCFS)'
                            : 'Pending',
                      ),
                      if (booking.checkedInAt != null) ...[
                        _infoRow('Session ID', booking.displaySessionId),
                        _infoRow(
                          'Start time',
                          timeFormat.format(booking.checkedInAt!.toLocal()),
                        ),
                      ],
                      if (booking.isParked)
                        _infoRow('Elapsed', booking.elapsedClock()),
                      if (booking.checkedOutAt != null)
                        _infoRow(
                          'Stop time',
                          timeFormat.format(booking.checkedOutAt!.toLocal()),
                        ),
                      if (booking.isAwaitingPayment ||
                          booking.status == BookingStatus.completed)
                        _infoRow('Duration', booking.billedDurationLabel),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                booking.vehicleNumber,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                booking.isParked
                    ? 'Session running'
                    : booking.isAwaitingEntry
                        ? 'Waiting for entry scan'
                        : booking.isAwaitingPayment
                            ? 'Awaiting payment'
                            : booking.status.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              if (booking.isQrLive) ...[
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
                const SizedBox(height: 4),
                Text(
                  'Keep this QR on your phone until payment is complete. '
                  'Re-open it anytime from Home or History.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _statusMessage(booking),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (booking.isAwaitingPayment) ...[
                const SizedBox(height: 16),
                Text(
                  '₹${booking.amountDue!.toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${booking.billedDurationLabel} × ₹${booking.hourlyRate.toStringAsFixed(0)}/hr',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push(
                    RoutePaths.vehicleOwnerPayBooking(booking.id),
                  ),
                  icon: const Icon(Icons.payment),
                  label: Text(
                    booking.amountDue! < 1
                        ? 'Complete checkout'
                        : 'Pay ₹${booking.amountDue!.toStringAsFixed(0)} with Razorpay',
                  ),
                ),
              ] else if (booking.status == BookingStatus.completed) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(
                    RoutePaths.vehicleOwnerBookingReceipt(booking.id),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('View receipt'),
                ),
              ] else
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(bookingDetailProvider(widget.bookingId)),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
