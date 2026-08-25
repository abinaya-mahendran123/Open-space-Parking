import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/location_permission_status.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/maps/presentation/utils/location_access.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/google_map_view.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/location_permission_banner.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_listing_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/search_filters_sheet.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';

class ParkingSearchPage extends ConsumerStatefulWidget {
  const ParkingSearchPage({super.key});

  @override
  ConsumerState<ParkingSearchPage> createState() => _ParkingSearchPageState();
}

class _ParkingSearchPageState extends ConsumerState<ParkingSearchPage> {
  final _searchController = TextEditingController();
  bool _locating = false;
  bool _showMap = true;
  bool _requestedInitialLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requestedInitialLocation) {
        _requestedInitialLocation = true;
        _useMyLocation(showSuccessMessage: false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation({bool showSuccessMessage = true}) async {
    setState(() => _locating = true);
    try {
      final mapsRepo = ref.read(mapsRepositoryProvider);
      final permission = await LocationAccess.ensure(
        context: context,
        repository: mapsRepo,
      );
      if (!mounted) return;

      if (!permission.isGranted) {
        final message = LocationAccess.messageFor(permission);
        ref.read(snackbarServiceProvider).showError(
              message.isEmpty
                  ? 'Allow location access to find nearby parking.'
                  : message,
            );
        ref.invalidate(locationPermissionProvider);
        return;
      }

      final location =
          await ref.read(mapSelectionProvider.notifier).refreshCurrentLocation();
      if (!mounted) return;

      if (location == null) {
        ref.read(snackbarServiceProvider).showError(
              'Could not read your current location. Check browser/GPS permission.',
            );
        return;
      }

      final current = ref.read(searchFiltersProvider);
      ref.read(searchFiltersProvider.notifier).state = current.copyWith(
        userLatitude: location.latitude,
        userLongitude: location.longitude,
      );
      ref.invalidate(locationPermissionProvider);
      ref.invalidate(parkingListingsProvider);

      if (showSuccessMessage) {
        ref.read(snackbarServiceProvider).showSuccess('Location found.');
      }
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError(
            'Could not get your location. Allow location for this site and try again.',
          );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openParking(ParkingListing listing) async {
    if (!mounted) return;
    final id = listing.id.trim();
    final key = (id.isNotEmpty &&
            id != '[object Object]' &&
            !id.contains('object Object'))
        ? id
        : listing.ticketId.trim();
    if (key.isEmpty) {
      ref.read(snackbarServiceProvider).showError(
            'This parking cannot be opened right now. Pull to refresh and try again.',
          );
      return;
    }
    context.push(RoutePaths.vehicleOwnerParkingDetail(key));
  }

  Future<void> _navigateTo(ParkingListing listing) async {
    final origin = ref.read(mapSelectionProvider).currentLocation;
    await ref.read(mapsRepositoryProvider).openNavigation(
          DirectionsRequest(
            destination: MapCoordinate(
              latitude: listing.latitude,
              longitude: listing.longitude,
            ),
            origin: origin,
          ),
        );
  }

  void _applySearch() {
    final current = ref.read(searchFiltersProvider);
    ref.read(searchFiltersProvider.notifier).state = current.copyWith(
      query: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      clearQuery: _searchController.text.trim().isEmpty,
    );
    ref.invalidate(parkingListingsProvider);
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SearchFiltersSheet(),
    ).then((_) => ref.invalidate(parkingListingsProvider));
  }

  List<MapMarkerData> _listingMarkers(List<ParkingListing> listings) {
    return listings
        .map(
          (listing) => MapMarkerData(
            id: listing.id,
            coordinate: MapCoordinate(
              latitude: listing.latitude,
              longitude: listing.longitude,
            ),
            title: listing.displayName,
            snippet: [
              listing.distanceLabel,
              listing.compatibilityLabel,
              '${listing.freeSlots} spaces available',
            ].whereType<String>().join(' • '),
            distanceKm: listing.distanceKm,
            payload: listing.id,
          ),
        )
        .toList();
  }

  Widget _buildResults(
    BuildContext context,
    List<ParkingListing> listings, {
    required bool hasLocation,
    bool isRefreshing = false,
  }) {
    if (listings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_parking_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No suitable parking found nearby.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                hasLocation
                    ? "We couldn't find an approved parking space that is currently available and compatible with your vehicle.\n\nTry expanding your search area."
                    : 'Allow location access or tap Current Location to find approved parking near you.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final markers = _listingMarkers(listings);

    if (_showMap) {
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(parkingListingsProvider),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (isRefreshing)
              const LinearProgressIndicator(minHeight: 2),
            GoogleMapView(
              height: 280,
              markers: markers,
              showCurrentLocation: true,
              initialZoom: hasLocation ? 13 : 12,
              onMarkerTap: (marker) {
                final match =
                    listings.where((l) => l.id == marker.payload).toList();
                if (match.isNotEmpty) _openParking(match.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Recommended for Your Vehicle',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${listings.length} approved parking location${listings.length == 1 ? '' : 's'} found',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...listings.map(
              (listing) => ParkingListingCard(
                listing: listing,
                onTap: () => _openParking(listing),
                onNavigate: () => _navigateTo(listing),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(parkingListingsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: listings.length + (isRefreshing ? 1 : 0),
        itemBuilder: (context, index) {
          if (isRefreshing && index == 0) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final listing = listings[isRefreshing ? index - 1 : index];
          return ParkingListingCard(
            listing: listing,
            onTap: () => _openParking(listing),
            onNavigate: () => _navigateTo(listing),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);
    final listingsAsync = ref.watch(parkingListingsProvider);
    final mapState = ref.watch(mapSelectionProvider);
    final hasLocation =
        filters.userLatitude != null && filters.userLongitude != null;
    final cachedListings = listingsAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Nearby Parking'),
        actions: [
          const VehicleOwnerLiveQrButton(),
          IconButton(
            onPressed: () => context.push(RoutePaths.nearbyParkingMap),
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Full map',
          ),
          IconButton(
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? 'List view' : 'Map view',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocationPermissionBanner(),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.my_location),
                    title: const Text('Your Location'),
                    subtitle: Text(
                      hasLocation && mapState.currentLocation != null
                          ? 'Current Location • ${mapState.currentLocation!.latitude.toStringAsFixed(4)}, ${mapState.currentLocation!.longitude.toStringAsFixed(4)}'
                          : 'Location not available yet',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SearchBar(
                  controller: _searchController,
                  hintText: 'Search by address or ticket ID',
                  leading: const Icon(Icons.search),
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applySearch();
                      },
                    ),
                  ],
                  onSubmitted: (_) => _applySearch(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _locating ? null : () => _useMyLocation(),
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          hasLocation ? 'Update Location' : 'Current Location',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _showFilters,
                        icon: const Icon(Icons.tune),
                        label: Text(
                          filters.hasActiveFilters ? 'Filters •' : 'Filters',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: listingsAsync.when(
              loading: () {
                if (cachedListings != null) {
                  return _buildResults(
                    context,
                    cachedListings,
                    hasLocation: hasLocation,
                    isRefreshing: true,
                  );
                }
                return const AppLoadingWidget(
                  message: 'Finding approved parking near you...',
                );
              },
              error: (_, __) => AppErrorWidget(
                message: 'Could not load parking recommendations.',
                onRetry: () => ref.invalidate(parkingListingsProvider),
              ),
              data: (listings) => _buildResults(
                context,
                listings,
                hasLocation: hasLocation,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
