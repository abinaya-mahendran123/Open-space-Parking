import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 20,
    this.showValue = false,
    this.reviewCount,
  });

  final double rating;
  final double size;
  final bool showValue;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          IconData icon;
          if (index < fullStars) {
            icon = Icons.star_rounded;
          } else if (index == fullStars && hasHalf) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return Icon(
            icon,
            size: size,
            color: theme.colorScheme.tertiary,
          );
        }),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: theme.textTheme.titleSmall,
          ),
          if (reviewCount != null)
            Text(
              ' ($reviewCount)',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class InteractiveRatingBar extends StatelessWidget {
  const InteractiveRatingBar({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 36,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return IconButton(
          onPressed: () => onRatingChanged(starValue),
          icon: Icon(
            starValue <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: color,
          ),
        );
      }),
    );
  }
}
