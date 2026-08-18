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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: ParkingTypeImage(
              parkingType: listing.parkingType,
              height: 140,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.displayName,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            listing.parkingType.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${listing.hourlyRate.toStringAsFixed(0)}/hr',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  listing.locationLabel,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ticket ${listing.ticketId}'
                  '${listing.verifiedEmployeeName != null ? ' • Verified by ${listing.verifiedEmployeeName}' : ' • Employee verified'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (listing.reviewCount > 0)
                  RatingStars(
                    rating: listing.averageRating,
                    size: 16,
                    showValue: true,
                    reviewCount: listing.reviewCount,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                      icon: Icons.directions_car,
                      label:
                          '${listing.availableSlots ?? listing.capacity} free',
                    ),
                    _InfoChip(
                      icon: Icons.square_foot,
                      label: '${listing.areaSqFt.toStringAsFixed(0)} sq ft',
                    ),
                    if (listing.distanceKm != null)
                      _InfoChip(
                        icon: Icons.near_me,
                        label:
                            '${listing.distanceKm!.toStringAsFixed(1)} km',
                      ),
                    if (listing.cctv)
                      const _InfoChip(icon: Icons.videocam, label: 'CCTV'),
                    if (listing.roadAccess)
                      const _InfoChip(icon: Icons.route, label: 'Road access'),
                    if (listing.verifiedByEmployee)
                      const _InfoChip(
                        icon: Icons.verified,
                        label: 'Verified',
                      ),
                    if (!listing.isAvailableNow)
                      Chip(
                        label: const Text('Full'),
                        backgroundColor: theme.colorScheme.errorContainer,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
