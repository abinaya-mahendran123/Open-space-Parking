import 'package:flutter/material.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
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
    final statusColor =
        ParkingListingCard._statusColor(listing.availabilityLevel);

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
                  listing.shortDisplayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (listing.distanceLabel != null) listing.distanceLabel,
                    listing.shortLocationLabel,
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.local_parking_outlined, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      '${listing.freeSlots} free',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (listing.amountLabel != null) ...[
                      const Spacer(),
                      Text(
                        listing.amountLabel!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.outline),
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
    final statusColor =
        ParkingListingCard._statusColor(listing.availabilityLevel);

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
                  listing.shortDisplayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  listing.parkingType.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (listing.distanceLabel != null)
                      _InfoChip(
                        icon: Icons.near_me,
                        label: listing.distanceLabel!,
                      ),
                    _InfoChip(
                      icon: Icons.local_parking_outlined,
                      label: '${listing.freeSlots} free',
                      color: statusColor,
                    ),
                  ],
                ),
                if (listing.amountLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    listing.amountLabel!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (onNavigate != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('Navigate'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
