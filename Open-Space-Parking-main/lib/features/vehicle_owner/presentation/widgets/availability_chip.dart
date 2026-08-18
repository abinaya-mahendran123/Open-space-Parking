import 'package:flutter/material.dart';

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
    final color = availability.isAvailable
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final onColor = availability.isAvailable
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;
    final label = availability.isAvailable
        ? '${availability.availableSlots} of ${availability.totalSlots} slots free'
        : 'Fully booked';

    if (compact) {
      return Chip(
        avatar: Icon(
          availability.isAvailable ? Icons.check_circle : Icons.block,
          size: 16,
          color: onColor,
        ),
        label: Text(label, style: TextStyle(color: onColor, fontSize: 12)),
        backgroundColor: color,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );
    }

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  availability.isAvailable
                      ? Icons.event_available
                      : Icons.event_busy,
                  color: onColor,
                ),
                const SizedBox(width: 8),
                Text(
                  availability.isAvailable ? 'Available' : 'Unavailable',
                  style: theme.textTheme.titleMedium?.copyWith(color: onColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: onColor)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: availability.totalSlots > 0
                    ? availability.bookedSlots / availability.totalSlots
                    : 0,
                minHeight: 6,
                backgroundColor: onColor.withValues(alpha: 0.2),
                color: onColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
