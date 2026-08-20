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
    this.onNavigate,
  });

  final ParkingListing listing;
  final VoidCallback onTap;
  final VoidCallback? onNavigate;

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
                        if (listing.isBestMatch)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Best Match',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                listing.displayName,
                                style: theme.textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (listing.distanceLabel != null)
                              _InfoChip(
                                icon: Icons.near_me,
                                label: listing.distanceLabel!,
                              ),
                            _InfoChip(
                              icon: Icons.directions_car_outlined,
                              label: listing.compatibilityLabel,
                              color: listing.isCompatible
                                  ? const Color(0xFF2E7D32)
                                  : theme.colorScheme.error,
                            ),
                            _InfoChip(
                              icon: Icons.local_parking_outlined,
                              label: '$free spaces available',
                              color: statusColor,
                            ),
                            _InfoChip(
                              icon: Icons.verified_outlined,
                              label: listing.parkingStatusLabel,
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onTap,
                                child: const Text('View Details'),
                              ),
                            ),
                            if (onNavigate != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: onNavigate,
                                  icon: const Icon(Icons.navigation, size: 18),
                                  label: const Text('Navigate'),
                                ),
                              ),
                            ],
                          ],
                        ),
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
