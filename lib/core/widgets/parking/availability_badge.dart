import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';

/// Shared availability pill — green / orange / red per spec.
class AvailabilityBadge extends StatelessWidget {
  const AvailabilityBadge({
    super.key,
    required this.freeSlots,
    required this.totalSlots,
    this.compact = false,
    this.showDot = true,
  });

  final int freeSlots;
  final int totalSlots;
  final bool compact;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final tier = AppColors.availabilityTier(freeSlots, totalSlots);
    final brightness = Theme.of(context).brightness;
    final color = AppColors.availabilityColorForTier(tier);
    final bg = AppColors.availabilityBackgroundForTier(tier, brightness);
    final label = compact
        ? (freeSlots <= 0
            ? 'Full'
            : '$freeSlots / ${totalSlots > 0 ? totalSlots : '?'}')
        : AppColors.availabilityLabel(freeSlots, totalSlots);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Verified parking chip.
class VerifiedParkingChip extends StatelessWidget {
  const VerifiedParkingChip({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14532D) : AppColors.availableLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: 14,
            color: isDark ? AppColors.brandMintLight : AppColors.available,
          ),
          const SizedBox(width: 4),
          Text(
            'Verified Parking',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? AppColors.brandMintLight : AppColors.available,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
