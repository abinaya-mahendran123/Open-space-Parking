import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/availability_chip.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_image_gallery.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_map_widget.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/rating_stars.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/review_list_section.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/slot_booked_dialog.dart';

class ParkingDetailPage extends ConsumerStatefulWidget {
  const ParkingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ParkingDetailPage> createState() => _ParkingDetailPageState();
}

class _ParkingDetailPageState extends ConsumerState<ParkingDetailPage> {
  bool _bookingSlot = false;

  Future<void> _openDirections(WidgetRef ref, ParkingListing listing) async {
    final origin = ref.read(mapSelectionProvider).currentLocation;
    final opened = await ref.read(mapsRepositoryProvider).openDirections(
          DirectionsRequest(
            destination: MapCoordinate(
              latitude: listing.latitude,
              longitude: listing.longitude,
            ),
            origin: origin,
          ),
        );
    if (!opened && mounted) {
      ref
          .read(snackbarServiceProvider)
          .showError('Could not open Google Maps directions.');
    }
  }

  Future<void> _onBookSlot(ParkingListing listing) async {
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null) {
      ref.read(snackbarServiceProvider).showError('Please sign in again.');
      return;
    }

    final profile =
        await ref.read(vehicleOwnerProfileProvider(ownerId).future);
    final plate = profile?.vehicleNumber?.trim() ?? '';
    if (Validators.vehicleNumber(plate) != null) {
      if (!mounted) return;
      context.push(RoutePaths.vehicleOwnerCheckIn(listing.id));
      return;
    }

    setState(() => _bookingSlot = true);
    try {
      final booking =
          await ref.read(vehicleOwnerRepositoryProvider).startParkingSession(
                vehicleOwnerId: ownerId,
                parkingListingId: listing.id,
                vehicleNumber: plate,
              );
      ref.invalidate(parkingListingsProvider);
      ref.invalidate(parkingAvailabilityProvider(listing.id));
      ref.invalidate(vehicleOwnerBookingsProvider(ownerId));
      if (!mounted) return;
      await showSlotBookedDialog(
        context,
        slot: booking.assignedSlot ?? 0,
        parkingName: listing.displayName,
      );
      if (!mounted) return;
      context.go(RoutePaths.vehicleOwnerParkingTicket(booking.id));
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not book a slot.');
    } finally {
      if (mounted) setState(() => _bookingSlot = false);
    }
  }

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
        ref.watch(authStateProvider).session?.email.split('@').first ?? 'User';
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
            return AppErrorWidget(
              message:
                  'Parking space not found. Go back and open it again from search.',
              onRetry: () =>
                  ref.invalidate(parkingListingProvider(widget.listingId)),
            );
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
                            showDirections: false,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _openDirections(ref, listing),
                            icon: const Icon(Icons.directions),
                            label: const Text('Get Directions'),
                          ),
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
                            label: _bookingSlot
                                ? 'Booking slot...'
                                : listing.isAvailableNow
                                    ? 'Book Slot'
                                    : 'Currently Unavailable',
                            onPressed: listing.isAvailableNow && !_bookingSlot
                                ? () => _onBookSlot(listing)
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(listing.displayName, style: theme.textTheme.titleLarge),
            ),
            if (listing.verifiedByEmployee)
              const Icon(Icons.verified, color: Color(0xFF1B8A3E)),
          ],
        ),
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
                : 'Documents verified',
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
            if (listing.amountLabel != null)
              Text(
                listing.amountLabel!,
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

