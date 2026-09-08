import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
import 'package:open_space_parking/core/widgets/parking/availability_badge.dart';
import 'package:open_space_parking/core/widgets/parking_type_image.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';

class ParkingListingCard extends StatelessWidget {
  const ParkingListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.onNavigate,
    this.compact = false,
  });

  final ParkingListing listing;
  final VoidCallback onTap;
  final VoidCallback? onNavigate;
  final bool compact;

  static String routeKeyFor(ParkingListing listing) {
    final id = listing.id.trim();
    if (id.isNotEmpty &&
        id != '[object Object]' &&
        !id.contains('object Object')) {
      return id;
    }
    return listing.ticketId.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _CompactCard(listing: listing, onTap: onTap);
    return _FullCard(listing: listing, onTap: onTap, onNavigate: onNavigate);
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.listing, required this.onTap});

  final ParkingListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 72,
              height: 72,
              child: ParkingTypeImage(
                parkingType: listing.parkingType,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.compactDisplayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (listing.distanceLabel != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.near_me_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.distanceLabel!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                AvailabilityBadge(
                  freeSlots: listing.freeSlots,
                  totalSlots: listing.capacity,
                  compact: true,
                ),
                if (listing.amountLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    listing.amountLabel!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.navigationBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (listing.verifiedByEmployee) ...[
                  const SizedBox(height: 6),
                  const VerifiedParkingChip(),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _FullCard extends StatelessWidget {
  const _FullCard({
    required this.listing,
    required this.onTap,
    this.onNavigate,
  });

  final ParkingListing listing;
  final VoidCallback onTap;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: ParkingTypeImage(
                    parkingType: listing.parkingType,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.compactDisplayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (listing.distanceLabel != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              listing.distanceLabel!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (listing.amountLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        listing.amountLabel!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.navigationBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AvailabilityBadge(
            freeSlots: listing.freeSlots,
            totalSlots: listing.capacity,
          ),
          if (listing.verifiedByEmployee) ...[
            const SizedBox(height: 8),
            const VerifiedParkingChip(),
          ],
          if (onNavigate != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.local_parking_outlined, size: 18),
                label: const Text('View parking'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
