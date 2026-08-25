import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
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
  static final _dateFormat = DateFormat('dd MMM, hh:mm a');

  bool _cancelling = false;

  Future<void> _cancel(String vehicleOwnerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, cancel'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: bookingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading...'),
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
          final amount =
              booking.paidAmount ?? booking.amountDue ?? booking.totalPrice;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.shortDisplayParkingName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _summaryLine('Slot', '${booking.assignedSlot ?? '-'}'),
                      _summaryLine('Vehicle', booking.vehicleNumber),
                      _summaryLine(
                        'Status',
                        booking.status.label,
                        valueColor: Theme.of(context).colorScheme.primary,
                      ),
                      if (booking.shortParkingAddress != null)
                        _summaryLine('Location', booking.shortParkingAddress!),
                      _summaryLine(
                        'Start',
                        _dateFormat.format(
                          (booking.checkedInAt ?? booking.startDateTime).toLocal(),
                        ),
                      ),
                      if (booking.checkedOutAt != null)
                        _summaryLine(
                          'End',
                          _dateFormat.format(booking.checkedOutAt!.toLocal()),
                        ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (booking.isQrLive)
                  PrimaryButton(
                    label: 'Show QR ticket',
                    icon: Icons.qr_code_2,
                    onPressed: () => context.push(
                      RoutePaths.vehicleOwnerParkingTicket(booking.id),
                    ),
                  ),
                if (booking.isAwaitingPayment) ...[
                  PrimaryButton(
                    label: 'Pay ₹${booking.amountDue!.toStringAsFixed(0)}',
                    icon: Icons.payment,
                    onPressed: () => context.push(
                      RoutePaths.vehicleOwnerPayBooking(booking.id),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (booking.status == BookingStatus.completed)
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      RoutePaths.vehicleOwnerBookingReceipt(booking.id),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View receipt'),
                  ),
                if (booking.isQrLive ||
                    booking.isAwaitingPayment ||
                    booking.status == BookingStatus.completed)
                  const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _openParkingDetail,
                  child: const Text('View parking'),
                ),
                if (canCancel &&
                    !booking.isParked &&
                    !booking.isAwaitingPayment) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _cancelling ? null : () => _cancel(vehicleOwnerId),
                    child: Text(
                      _cancelling ? 'Cancelling...' : 'Cancel booking',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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

  Widget _summaryLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
