import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/core/widgets/parking/availability_badge.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_image_gallery.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/slot_booked_dialog.dart';

class ParkingDetailPage extends ConsumerStatefulWidget {
  const ParkingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ParkingDetailPage> createState() => _ParkingDetailPageState();
}

class _ParkingDetailPageState extends ConsumerState<ParkingDetailPage> {
  bool _bookingSlot = false;
  bool _redirectedToQr = false;

  Future<void> _openDirections(ParkingListing listing) async {
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

    final liveForListing = ref.read(
      liveQrForListingProvider((ownerId: ownerId, listingId: listing.id)),
    );
    final liveQr =
        liveForListing ?? ref.read(liveQrBookingProvider(ownerId));
    if (liveQr != null) {
      if (!mounted) return;
      context.go(RoutePaths.vehicleOwnerParkingTicket(liveQr.id));
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
        parkingName: listing.compactDisplayName,
      );
      if (!mounted) return;
      context.go(RoutePaths.vehicleOwnerParkingTicket(booking.id));
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
      ref.invalidate(vehicleOwnerBookingsProvider(ownerId));
      final live = ref.read(liveQrBookingProvider(ownerId));
      if (live != null && mounted) {
        context.go(RoutePaths.vehicleOwnerParkingTicket(live.id));
      }
    } catch (e) {
      final message = e is NetworkException ? e.message : 'Could not book a slot.';
      ref.read(snackbarServiceProvider).showError(message);
      final live = ref.read(liveQrBookingProvider(ownerId));
      if (live != null && mounted) {
        context.go(RoutePaths.vehicleOwnerParkingTicket(live.id));
      }
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

  Widget _availabilitySection(ParkingListing listing) {
    return AvailabilityBadge(
      freeSlots: listing.freeSlots,
      totalSlots: listing.capacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';
    final listingAsync = ref.watch(parkingListingProvider(widget.listingId));
    final favoriteAsync = ref.watch(isFavoriteProvider(
      (ownerId: vehicleOwnerId, listingId: widget.listingId),
    ));
    final liveForListing = ref.watch(
      liveQrForListingProvider(
        (ownerId: vehicleOwnerId, listingId: widget.listingId),
      ),
    );
    final liveAny = ref.watch(liveQrBookingProvider(vehicleOwnerId));
    final liveQr = liveForListing ?? liveAny;

    // If this parking already has their live slot, jump straight to QR.
    if (liveForListing != null && !_redirectedToQr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _redirectedToQr) return;
        _redirectedToQr = true;
        context.go(RoutePaths.vehicleOwnerParkingTicket(liveForListing.id));
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Parking'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        actions: [
          favoriteAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (isFavorite) => IconButton(
              onPressed: () => _toggleFavorite(vehicleOwnerId),
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
      body: listingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load parking details',
          onRetry: () => ref.invalidate(parkingListingProvider(widget.listingId)),
        ),
        data: (listing) {
          if (listing == null) {
            return AppErrorWidget(
              message: 'Parking space not found.',
              onRetry: () =>
                  ref.invalidate(parkingListingProvider(widget.listingId)),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.isDesktop ? 720 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      listing.compactDisplayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.parkingType.label,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                        if (listing.amountLabel != null)
                          Text(
                            listing.amountLabel!,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            listing.shortLocationLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (listing.distanceLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        listing.distanceLabel!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                          _availabilitySection(listing),
                    if (listing.verifiedByEmployee) ...[
                      const SizedBox(height: 10),
                      const VerifiedParkingChip(),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => _openDirections(listing),
                      icon: const Icon(Icons.directions),
                      label: const Text('Get Directions'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: _bookingSlot
                          ? 'Booking...'
                          : liveQr != null
                              ? 'Show parking QR'
                              : listing.isAvailableNow
                                  ? 'Book Slot'
                                  : 'Unavailable',
                      onPressed: _bookingSlot
                          ? null
                          : liveQr != null
                              ? () => context.go(
                                    RoutePaths.vehicleOwnerParkingTicket(
                                      liveQr.id,
                                    ),
                                  )
                              : listing.isAvailableNow
                                  ? () => _onBookSlot(listing)
                                  : null,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Parking photo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ParkingImageGallery(
                      imageAssets: listing.imageAssets,
                      height: 220,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
