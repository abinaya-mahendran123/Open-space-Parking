import 'package:flutter/material.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
import 'package:open_space_parking/core/widgets/parking_type_image.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/rating_stars.dart';

class ParkingListingCard extends StatelessWidget {
  const ParkingListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  final ParkingListing listing;
  final VoidCallback onTap;

  static Color _statusColor(ParkingAvailabilityLevel level) {
    switch (level) {
      case ParkingAvailabilityLevel.high:
        return const Color(0xFF2E7D32);
      case ParkingAvailabilityLevel.medium:
        return const Color(0xFFEF6C00);
      case ParkingAvailabilityLevel.none:
        return const Color(0xFFC62828);
    }
  }

  static String _statusLabel(ParkingAvailabilityLevel level, int free) {
    switch (level) {
      case ParkingAvailabilityLevel.high:
        return '$free seats available';
      case ParkingAvailabilityLevel.medium:
        return '$free seats left';
      case ParkingAvailabilityLevel.none:
        return 'No seats available';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = listing.availabilityLevel;
    final statusColor = _statusColor(level);
    final free = listing.freeSlots;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: statusColor),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                    ),
                    child: ParkingTypeImage(
                      parkingType: listing.parkingType,
                      height: 120,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      listing.displayName,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (listing.verifiedByEmployee) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified,
                                      size: 20,
                                      color: Color(0xFF1B8A3E),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (listing.amountLabel != null)
                              Text(
                                listing.amountLabel!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          listing.parkingType.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_seat,
                                size: 16,
                                color: statusColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _statusLabel(level, free),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _InfoChip(
                              icon: Icons.directions_car,
                              label: '$free / ${listing.capacity} slots',
                              color: statusColor,
                            ),
                            if (listing.amountLabel != null)
                              _InfoChip(
                                icon: Icons.currency_rupee,
                                label: listing.amountLabel!,
                              ),
                            if (listing.distanceKm != null)
                              _InfoChip(
                                icon: Icons.near_me,
                                label:
                                    '${listing.distanceKm!.toStringAsFixed(1)} km',
                              ),
                          ],
                        ),
                        if (listing.reviewCount > 0) ...[
                          const SizedBox(height: 8),
                          RatingStars(
                            rating: listing.averageRating,
                            size: 16,
                            showValue: true,
                            reviewCount: listing.reviewCount,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: color != null ? FontWeight.w600 : null,
              ),
        ),
      ],
    );
  }
}
