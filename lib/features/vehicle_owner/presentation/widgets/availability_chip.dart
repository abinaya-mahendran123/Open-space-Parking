import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_availability.dart';

class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({
    super.key,
    required this.availability,
    this.compact = false,
  });

  final ParkingAvailability availability;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = AppColors.availabilityTier(
      availability.availableSlots,
      availability.totalSlots,
    );
    final color = AppColors.availabilityColorForTier(tier);
    final bg = AppColors.availabilityBackgroundForTier(tier);
    final label = AppColors.availabilityLabel(
      availability.availableSlots,
      availability.totalSlots,
    );

    if (compact) {
      return Chip(
        avatar: Icon(
          tier == 0 ? Icons.block : Icons.local_parking_outlined,
          size: 16,
          color: color,
        ),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        backgroundColor: bg,
        side: BorderSide(color: color.withValues(alpha: 0.25)),
        visualDensity: VisualDensity.compact,
      );
    }

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  tier == 0 ? Icons.event_busy : Icons.event_available,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  tier == 0
                      ? 'Full'
                      : tier == 2
                          ? 'Available'
                          : 'Limited',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: availability.totalSlots > 0
                    ? availability.bookedSlots / availability.totalSlots
                    : 0,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.2),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
