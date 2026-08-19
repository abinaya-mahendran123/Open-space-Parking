import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_review.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/rating_stars.dart';

class ReviewListSection extends StatelessWidget {
  const ReviewListSection({
    super.key,
    required this.reviews,
    required this.summary,
    this.onWriteReview,
  });

  static final _dateFormat = DateFormat('dd MMM yyyy');

  final List<ParkingReview> reviews;
  final ParkingRatingSummary summary;
  final VoidCallback? onWriteReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Reviews & Ratings', style: theme.textTheme.titleLarge),
            if (onWriteReview != null)
              TextButton.icon(
                onPressed: onWriteReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Write'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (summary.reviewCount > 0) ...[
          Row(
            children: [
              Text(
                summary.averageRating.toStringAsFixed(1),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RatingStars(rating: summary.averageRating, size: 18),
                  Text(
                    '${summary.reviewCount} review${summary.reviewCount == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reviews.take(5).map((review) => _ReviewTile(
                review: review,
                dateFormat: _dateFormat,
              )),
          if (reviews.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${reviews.length - 5} more reviews',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ] else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 40,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  const Text('No reviews yet. Be the first to rate this parking!'),
                  if (onWriteReview != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: onWriteReview,
                      child: const Text('Write a Review'),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.dateFormat,
  });

  final ParkingReview review;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(review.reviewerName.isNotEmpty
              ? review.reviewerName[0].toUpperCase()
              : '?'),
        ),
        title: Row(
          children: [
            Expanded(child: Text(review.reviewerName)),
            RatingStars(rating: review.rating.toDouble(), size: 14),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(review.comment),
            ],
            const SizedBox(height: 4),
            Text(
              dateFormat.format(review.createdAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: review.comment.isNotEmpty,
      ),
    );
  }
}
