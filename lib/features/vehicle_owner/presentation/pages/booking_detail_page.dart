import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';

class BookingDetailPage extends ConsumerStatefulWidget {
  const BookingDetailPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends ConsumerState<BookingDetailPage> {
  bool _cancelling = false;

  Future<void> _cancel(String vehicleOwnerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(vehicleOwnerRepositoryProvider).cancelBooking(widget.bookingId);
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId));
      invalidateNotificationCache(
        ref,
        recipientId: vehicleOwnerId,
        recipientType: NotificationRecipientType.vehicleOwner,
      );
      ref.invalidate(vehicleOwnerUnreadCountProvider(vehicleOwnerId));
      ref.read(snackbarServiceProvider).showSuccess('Booking cancelled.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not cancel booking.');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _openParkingDetail() async {
    final booking = await ref.read(bookingDetailProvider(widget.bookingId).future);
    if (booking == null || !mounted) return;
    context.push(RoutePaths.vehicleOwnerParkingDetail(booking.parkingListingId));
  }

  @override
  Widget build(BuildContext context) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: bookingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading booking...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load booking',
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Booking not found.'));
          }

          final canCancel = booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.pending ||
              booking.status == BookingStatus.active;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.displayParkingName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text('Session: ${booking.displaySessionId}'),
                        Text('Slot ${booking.assignedSlot ?? '-'}'),
                        const SizedBox(height: 8),
                        Chip(label: Text(booking.status.label)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _DetailTile(
                  icon: Icons.schedule,
                  label: 'Start',
                  value: dateFormat.format(
                    (booking.checkedInAt ?? booking.startDateTime).toLocal(),
                  ),
                ),
                if (booking.checkedOutAt != null ||
                    (!booking.isParked && !booking.isAwaitingEntry))
                  _DetailTile(
                    icon: Icons.schedule,
                    label: booking.checkedOutAt != null ? 'Stop' : 'End',
                    value: dateFormat.format(
                      (booking.checkedOutAt ?? booking.endDateTime).toLocal(),
                    ),
                  ),
                _DetailTile(
                  icon: Icons.directions_car,
                  label: 'Vehicle',
                  value: booking.vehicleNumber,
                ),
                if (booking.vehicleModel != null)
                  _DetailTile(
                    icon: Icons.car_rental,
                    label: 'Model',
                    value: booking.vehicleModel!,
                  ),
                if (booking.parkingAddress != null)
                  _DetailTile(
                    icon: Icons.location_on,
                    label: 'Address',
                    value: booking.parkingAddress!,
                  ),
                if (booking.assignedSlot != null)
                  _DetailTile(
                    icon: Icons.pin,
                    label: 'Slot',
                    value: '${booking.assignedSlot}',
                  ),
                if (booking.actualDurationHours != null)
                  _DetailTile(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: booking.billedDurationLabel,
                  ),
                _DetailTile(
                  icon: Icons.payments,
                  label: booking.paidAt != null ? 'Total Paid' : 'Amount',
                  value:
                      '₹${(booking.paidAmount ?? booking.amountDue ?? booking.totalPrice).toStringAsFixed(0)}',
                ),
                const SizedBox(height: 24),
                if (booking.isQrLive) ...[
                  FilledButton.icon(
                    onPressed: () => context.push(
                      RoutePaths.vehicleOwnerParkingTicket(booking.id),
                    ),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Show QR Ticket'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (booking.isAwaitingPayment) ...[
                  PrimaryButton(
                    label:
                        'Pay ₹${booking.amountDue!.toStringAsFixed(0)} with Razorpay',
                    onPressed: () => context.push(
                      RoutePaths.vehicleOwnerPayBooking(booking.id),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (booking.status == BookingStatus.completed) ...[
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      RoutePaths.vehicleOwnerBookingReceipt(booking.id),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View Receipt'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _openParkingDetail,
                  icon: const Icon(Icons.local_parking),
                  label: const Text('View Parking Space'),
                ),
                if (canCancel &&
                    !booking.isParked &&
                    !booking.isAwaitingPayment) ...[
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Cancel Booking',
                    isLoading: _cancelling,
                    onPressed: _cancelling ? null : () => _cancel(vehicleOwnerId),
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

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
