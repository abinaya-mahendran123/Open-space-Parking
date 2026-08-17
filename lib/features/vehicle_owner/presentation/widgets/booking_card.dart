import 'package:flutter/material.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    this.onShowQr,
  });

  final Booking booking;
  final VoidCallback onTap;
  final VoidCallback? onShowQr;

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.active:
        return Colors.blue;
      case BookingStatus.completed:
        return Colors.teal;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.pending:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _statusColor(booking.status).withValues(alpha: 0.15),
          child: Icon(
            Icons.local_parking,
            color: _statusColor(booking.status),
          ),
        ),
        title: Text(booking.displayParkingName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Slot ${booking.assignedSlot ?? '-'} • ${booking.vehicleNumber}',
            ),
            Text(
              booking.isAwaitingPayment
                  ? 'Pay ₹${(booking.amountDue ?? 0).toStringAsFixed(0)} • ${booking.displaySessionId}'
                  : booking.isParked
                      ? 'Session ${booking.displaySessionId}'
                      : booking.status.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: _statusColor(booking.status),
              ),
            ),
          ],
        ),
        trailing: booking.isQrLive
            ? IconButton(
                tooltip: 'Show parking QR',
                onPressed: onShowQr ?? onTap,
                icon: const Icon(Icons.qr_code_2),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${booking.totalPrice.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
        isThreeLine: true,
      ),
    );
  }
}
