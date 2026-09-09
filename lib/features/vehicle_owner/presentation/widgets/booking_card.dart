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
    this.onDelete,
    this.selecting = false,
    this.selected = false,
    this.onSelectedChanged,
  });

  final Booking booking;
  final VoidCallback onTap;
  final VoidCallback? onShowQr;
  final VoidCallback? onDelete;
  final bool selecting;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  Color _statusColor(
    BookingStatus status,
    ColorScheme scheme,
  ) {
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

    if (booking.isParked) {
      return 'Parked · ${booking.elapsedClock()}';
    }

    if (booking.isAwaitingEntry) {
      return 'Show QR at entry';
    }

    if (booking.wasCancelledForEntryQrExpiry) {
      return 'Cancelled · QR not scanned in 2h';
    }

    return booking.status.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = _statusColor(
      booking.status,
      scheme,
    );

    return AppCard(
      onTap: selecting
          ? () => onSelectedChanged?.call(!selected)
          : onTap,
      margin: const EdgeInsets.only(
        bottom: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Selection checkbox
          if (selecting) ...[
            Checkbox(
              value: selected,
              onChanged: onSelectedChanged == null
                  ? null
                  : (value) =>
                      onSelectedChanged!(value ?? false),
            ),
            const SizedBox(width: 4),
          ],

          // Status / QR icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              booking.isQrLive
                  ? Icons.qr_code_2
                  : Icons.local_parking_outlined,
              color: statusColor,
            ),
          ),

          const SizedBox(width: 12),

          // Booking information
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
                  'Slot ${booking.assignedSlot ?? '-'} · '
                  '${booking.vehicleNumber}',
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

          // QR button
          if (!selecting && booking.isQrLive)
            IconButton(
              tooltip: 'Show QR',
              onPressed: onShowQr ?? onTap,
              icon: const Icon(
                Icons.qr_code_2,
              ),
            )

          // Price + delete button
          else if (!selecting)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${booking.totalPrice.toStringAsFixed(0)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.outline,
                ),

                // Delete from booking history
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete from history',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}