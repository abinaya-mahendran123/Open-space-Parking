import 'package:flutter/material.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';

/// Displays a parking type illustration with a graceful fallback when assets are missing.
class ParkingTypeImage extends StatelessWidget {
  const ParkingTypeImage({
    super.key,
    required this.parkingType,
    this.height = 140,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final ParkingType parkingType;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.asset(
        parkingType.imageAsset,
        height: height,
        width: double.infinity,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: double.infinity,
          color: colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_parking_outlined,
                size: 40,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                parkingType.label,
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
