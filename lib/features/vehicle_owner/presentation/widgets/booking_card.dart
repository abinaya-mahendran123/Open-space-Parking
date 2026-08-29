import 'package:flutter/material.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
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

  Color _statusColor(BookingStatus status, ColorScheme scheme) {
    switch (status) {
      case BookingStatus.confirmed:
        return AppColors.availableHigh;
      case BookingStatus.active:
        return scheme.primary;
      case BookingStatus.completed:
        return AppColors.brandBlue;
      case BookingStatus.cancelled:
        return scheme.error;
      case BookingStatus.pending:
        return AppColors.availableMedium;
    }
  }

  String _statusLabel(Booking booking) {
    if (booking.isAwaitingPayment) {
      return 'Pay ₹${(booking.amountDue ?? 0).toStringAsFixed(0)}';
    }
    if (booking.isParked) return 'Parked · ${booking.elapsedClock()}';
    if (booking.isAwaitingEntry) return 'Show QR at entry';
    return booking.status.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = _statusColor(booking.status, scheme);

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              booking.isQrLive ? Icons.qr_code_2 : Icons.local_parking_outlined,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.shortDisplayParkingName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Slot ${booking.assignedSlot ?? '-'} · ${booking.vehicleNumber}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(booking),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (booking.isQrLive)
            IconButton(
              tooltip: 'Show QR',
              onPressed: onShowQr ?? onTap,
              icon: const Icon(Icons.qr_code_2),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${booking.totalPrice.toStringAsFixed(0)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: scheme.outline),
              ],
            ),
        ],
      ),
    );
  }
}
