import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/availability_chip.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_image_gallery.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_map_widget.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/rating_stars.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/review_list_section.dart';

class ParkingDetailPage extends ConsumerStatefulWidget {
  const ParkingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ParkingDetailPage> createState() => _ParkingDetailPageState();
}

class _ParkingDetailPageState extends ConsumerState<ParkingDetailPage> {
  Future<void> _toggleFavorite(String vehicleOwnerId) async {
    try {
      await ref.read(vehicleOwnerRepositoryProvider).toggleFavorite(
            vehicleOwnerId: vehicleOwnerId,
            parkingListingId: widget.listingId,
          );
      ref.invalidate(isFavoriteProvider(
        (ownerId: vehicleOwnerId, listingId: widget.listingId),
      ));
      ref.invalidate(favoritesProvider(vehicleOwnerId));
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    }
  }

  Future<void> _showReviewDialog(
    String vehicleOwnerId,
    String reviewerName,
  ) async {
    var rating = 5;
    final commentController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Write a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InteractiveRatingBar(
                rating: rating,
                onRatingChanged: (v) => setDialogState(() => rating = v),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: commentController,
                label: 'Your review (optional)',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;

    try {
      await ref.read(vehicleOwnerRepositoryProvider).submitReview(
            parkingListingId: widget.listingId,
            vehicleOwnerId: vehicleOwnerId,
            reviewerName: reviewerName,
            rating: rating,
            comment: commentController.text,
          );
      ref.invalidate(parkingReviewsProvider(widget.listingId));
      ref.invalidate(parkingRatingSummaryProvider(widget.listingId));
      ref.invalidate(parkingListingProvider(widget.listingId));
      ref.read(snackbarServiceProvider).showSuccess('Review submitted!');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    }
    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';
    final displayName =
        ref.watch(authStateProvider).session?.email?.split('@').first ?? 'User';
    final listingAsync = ref.watch(parkingListingProvider(widget.listingId));
    final availabilityAsync =
        ref.watch(parkingAvailabilityProvider(widget.listingId));
    final reviewsAsync = ref.watch(parkingReviewsProvider(widget.listingId));
    final summaryAsync = ref.watch(parkingRatingSummaryProvider(widget.listingId));
    final favoriteAsync = ref.watch(isFavoriteProvider(
      (ownerId: vehicleOwnerId, listingId: widget.listingId),
    ));

    return Scaffold(
      body: listingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading details...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load parking details',
          onRetry: () => ref.invalidate(parkingListingProvider(widget.listingId)),
        ),
        data: (listing) {
          if (listing == null) {
            return const Center(child: Text('Parking space not found.'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                expandedHeight: 280,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    listing.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: ParkingImageGallery(
                    imageAssets: listing.imageAssets,
                    height: 280,
                  ),
                ),
                actions: [
                  favoriteAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (isFavorite) => IconButton(
                      onPressed: () => _toggleFavorite(vehicleOwnerId),
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.isDesktop ? 720 : double.infinity,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeaderSection(listing: listing),
                          const SizedBox(height: 16),
                          availabilityAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (availability) =>
                                AvailabilityChip(availability: availability),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Location',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ParkingMapWidget(
                            latitude: listing.latitude,
                            longitude: listing.longitude,
                            title: listing.displayName,
                            height: 200,
                          ),
                          const SizedBox(height: 24),
                          _AmenitiesSection(listing: listing),
                          const SizedBox(height: 24),
                          reviewsAsync.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (reviews) => summaryAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (summary) => ReviewListSection(
                                reviews: reviews,
                                summary: summary,
                                onWriteReview: () => _showReviewDialog(
                                  vehicleOwnerId,
                                  displayName,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: listing.isAvailableNow
                                ? 'Go & Park Now'
                                : 'Currently Unavailable',
                            onPressed: listing.isAvailableNow
                                ? () => context.push(
                                      RoutePaths.vehicleOwnerCheckIn(
                                        listing.id,
                                      ),
                                    )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: listing.isAvailableNow
                                ? () => context.push(
                                      RoutePaths.vehicleOwnerBookParking(
                                        listing.id,
                                      ),
                                    )
                                : null,
                            child: const Text('Schedule for later'),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.listing});

  final ParkingListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(listing.displayName, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '${listing.parkingType.label} • ${listing.ticketId}',
          style: theme.textTheme.bodyMedium,
        ),
        if (listing.verifiedByEmployee) ...[
          const SizedBox(height: 4),
          Text(
            listing.verifiedEmployeeName != null
                ? 'Verified by ${listing.verifiedEmployeeName}'
                : 'Employee verified',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            if (listing.reviewCount > 0)
              RatingStars(
                rating: listing.averageRating,
                size: 20,
                showValue: true,
                reviewCount: listing.reviewCount,
              )
            else
              Text('No ratings yet', style: theme.textTheme.bodySmall),
            const Spacer(),
            Text(
              '₹${listing.hourlyRate.toStringAsFixed(0)}/hr',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Expanded(
              child: Text(listing.locationLabel, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ],
    );
  }
}

class _AmenitiesSection extends StatelessWidget {
  const _AmenitiesSection({required this.listing});

  final ParkingListing listing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _AmenityChip(
          icon: Icons.directions_car,
          label: '${listing.capacity} slots',
        ),
        _AmenityChip(
          icon: Icons.square_foot,
          label: '${listing.areaSqFt.toStringAsFixed(0)} sq ft',
        ),
        _AmenityChip(
          icon: Icons.route,
          label: listing.roadAccess ? 'Road access' : 'No road access',
        ),
        _AmenityChip(
          icon: Icons.videocam,
          label: listing.cctv ? 'CCTV' : 'No CCTV',
        ),
        if (listing.distanceKm != null)
          _AmenityChip(
            icon: Icons.near_me,
            label: '${listing.distanceKm!.toStringAsFixed(1)} km',
          ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
